# Build the certificate authority

**Goal:** Deploy step-ca on `ca01`, put automation, people and hosts on short-lived certificates, then remove standing keys.

**Why:** [ADR-0004](../adr/0004-step-ca-for-certificates.md). **Accept with:** [ATP-003](../atp/ATP-003-certificates-and-ssh.md). **Using it:** [Use certificates](using-certificates.md). **Failures:** [Rotation and compromise](../runbooks/certificate-rotation-and-compromise.md).

## Components

| Piece | Location | Function |
|---|---|---|
| `step-ca` | `ca01:443` | Automation and hosts: JWK provisioners `ansible`, `tofu`, `hosts` |
| `step-ca-login` | `ca01:8443` | People: OIDC provisioner `authentik` |
| Database `stepca` | `pg01:5432` | Issued certificates, revocations, used tokens |
| `roles/ssh_ca` | Every host | Trust, principal files, KRL, host certificate |
| Controllers | Workstation, `paw01` | `bin/ca-init`, `bin/ssh-cert`; sign host keys |

| Who | Lifetime | Contents forced by templates |
|---|---|---|
| Ansible, OpenTofu | 8 h, max 12 h | Fixed principal; X.509 CN |
| Hosts | 90 days, renewed at 30 left | Inventory names and `*.<domain>` only |
| People | 16 h, max 24 h | Principal = Authentik username, key ID = e-mail |
| Break-glass | 1 h, max 8 h | Key ID `breakglass:<account>@<host>:<time>` |

Network paths are host-to-host. **Guests have no path to `ca01`:** the controller signs and pushes.

## Prerequisites

- [Platform tier](platform-tier.md) built through step 6.
- Tools on the controller: `step`, `sops`, `age`, `jq`, Bash 4+, OpenSSL. `step` must match `step_cli_version`.
- Both controller addresses are in both places (`unifi_workstation`/`unifi_paw` and `lab_controllers`). `roles/postgres` fails if they differ.

## Phase 1: build

1. **Secrets, network, guest.** Expect the plan to show the `ca01` container, its firewall, and a `pg01` rule.
   ```bash
   bin/gen-service-secrets prod
   ```
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml
   ```
   ```bash
   bin/tf-platform prod plan && bin/tf-platform prod apply
   ```
2. **Configure the container.** The root run works only once, because the baseline then sets `PermitRootLogin no`. A second attempt fails with `Permission denied`, which is expected.
   ```bash
   bin/ap prod playbooks/platform.yml --limit ca01 -e ansible_user=root
   ```
   ```bash
   bin/ap prod playbooks/platform.yml
   ```
3. **Create the CA.** This prints the root fingerprint. Record it with the age key backup: it is how a new workstation knows it has the right root.
   ```bash
   bin/ca-init prod
   ```
   Commit `secrets/ca-prod*.enc.yaml` and `ansible/files/prod/ca01-*` to your private fork.
4. **Authentik application and group.** Expect the group `ssh-admins`, provider and application `step-ca`, and 2 bindings. Add yourself to the group.
   ```bash
   bin/tf-ak prod plan && bin/tf-ak prod apply
   ```
   ```bash
   curl -s https://auth.example.com/application/o/step-ca/.well-known/openid-configuration | jq -r .issuer
   ```
5. **Start the CA.**
   ```bash
   bin/ap prod playbooks/platform.yml
   ```
   ```bash
   source bin/lib/platform.sh && platform_env prod "$PWD"
   ```
   ```bash
   curl -s --cacert "$PLATFORM_CA_ROOT" "$PLATFORM_CA_URL/health"
   ```
   If `step-ca-login` is down, `journalctl -u step-ca-login` names the OIDC problem.
6. **Automation certificates.** `bin/ap` and `bin/tf` do this on every run from now on.
   ```bash
   bin/ssh-cert prod ansible && bin/ssh-cert prod tofu && bin/ssh-cert prod x509 ansible
   ```
   ```bash
   bin/ssh-cert prod status
   ```
7. **Every host trusts the CA.** The run tries the certificate first and the static key second, so it works on hosts in either state. `sshd -t` must pass before a reload; if it fails, the drop-in is removed.
   ```bash
   bin/ap prod playbooks/ssh-ca.yml --limit pve_nodes
   ```
   ```bash
   bin/ap prod playbooks/ssh-ca.yml
   ```
   Check for `ED25519-CERT host certificate` and `Authenticated`; Wazuh shows rule 100450.
   ```bash
   ssh -v -o IdentitiesOnly=yes -i ~/.ssh/labstack/prod/ansible ansible@git01 true 2>&1 | grep -E 'host certificate|Authenticated'
   ```
8. **OpenTofu.** `bin/tf` starts a private ssh-agent holding only the `tofu` certificate, so unrelated keys cannot use up `MaxAuthTries`.
   ```bash
   bin/tf prod plan
   ```
9. **Forgejo.** This passes the user CA to Forgejo and signs its container's host key. Each person then adds their username under Settings, SSH / GPG Keys, Manage SSH Certificate Principals.
   ```bash
   bin/ap prod playbooks/services.yml --limit git01
   ```
10. **OpenBao with certificates.** Set `PLATFORM_BAO_AUTH=cert` in `client.env`. The smoke test must not mention falling back to AppRole.
    ```bash
    bin/tf-bao prod plan && bin/tf-bao prod apply
    ```
    ```bash
    bin/ap prod playbooks/openbao-smoke.yml
    ```
11. **People.** Add each person to `ssh_ca_people` in `inventories/common/group_vars/all/ssh_ca.yml`, then run `ssh-ca.yml`:
    ```yaml
    ssh_ca_people:
      - { name: alice, comment: "Alice Admin", sudo: true }
    ```

## Phase 2: no standing keys

All must be true first:

- [ ] Every host has had `ssh-ca.yml` (Wazuh shows 100450 for each).
- [ ] `bin/tf prod plan` works with the `tofu` certificate.
- [ ] Break-glass was tested once, and rule 100451 fired.
- [ ] You know the console path for each guest (`pct enter <vmid>`, `qm guest exec <vmid>`).

Set `ssh_ca_enforce: true`, then:

```bash
bin/ap prod playbooks/ssh-ca.yml
```
```bash
bin/ap prod playbooks/services.yml --limit siem01
```

For each account on each host, the run first proves a login with the exact certificate, and only then deletes `authorized_keys`. Wazuh gains rule 100452 for plain-key logins.

**Confirm:** the static key is refused, and the certificate works.
```bash
ssh -o IdentitiesOnly=yes -o IdentityAgent=none -i ~/.ssh/id_ed25519_ansible ansible@git01 true
```
```bash
LABSTACK_SSH=cert bin/ap prod playbooks/ssh-ca.yml --check
```

**What still uses static keys:** first runs of new guests; root on nodes (cluster SSH); root on LXCs, where the key exists but `PermitRootLogin no` blocks it.

## Upgrade

Change `step_ca_version`, `step_cli_version` and their `*_sha256` from the release's `checksums.txt`, then run the play. Upgrade the controller's CLI to match.

```bash
bin/ap prod playbooks/platform.yml --limit step_ca
```
