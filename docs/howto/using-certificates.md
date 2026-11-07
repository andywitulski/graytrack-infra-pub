# Use certificates

**Goal:** Log in with short-lived certificates, use git over SSH, and carry out routine CA tasks.

**Why:** [ADR-0004](../adr/0004-step-ca-for-certificates.md). **Build:** [CA guide](certificate-authority.md).

## How it works

- A certificate is a signed statement: "this key belongs to `ansible` until 18:00". sshd checks the signature, expiry, KRL, and whether a principal is listed in `/etc/ssh/auth_principals/<account>`. No `authorized_keys` is involved.
- Hosts prove who they are as well. A `known_hosts` `@cert-authority` line trusts the host CA, so a rebuilt host is still trusted.
- Losing a certificate costs little. Losing a provisioner password or CA key costs a rotation.

## Log in to a host

```bash
bin/ssh-cert prod login alice@example.com
```
```bash
ssh alice@git01
```

The browser opens Authentik, with MFA, and the certificate lands in ssh-agent for 16 hours. `ssh-add -L | ssh-keygen -L -f /dev/stdin` shows what you hold.

**Without a browser on the machine,** forward the callback port and open the printed URL locally:

```bash
ssh -L 10000:127.0.0.1:10000 paw01
```

**Keep a certificate without thinking about it** (launchd on macOS, a systemd user timer on Linux, every 2 hours, renews under 4 hours left):

```bash
bin/ssh-cert prod autorenew install alice@example.com
```

## Set up another workstation

No repository or age key is needed, only public files.

1. Install `step`, copy `ca01-root.pem` to `~/.labstack/prod-root.pem`, and compare the fingerprint with your record:
   ```bash
   step certificate fingerprint ~/.labstack/prod-root.pem
   ```
2. Add the host CA to `known_hosts`:
   ```text
   @cert-authority *.example.com,[*.example.com]:*,__MGMT_NET__.*,__SEC_NET__.*,__SVC_NET__.*,__DMZ_NET__.* <contents of ca01-ssh-host-ca.pub>
   ```
3. Add a login helper:
   ```bash
   step ssh login alice@example.com --provisioner authentik --ca-url https://__MGMT_NET__.24:8443 --root ~/.labstack/prod-root.pem
   ```

Only admin addresses can reach `ca01`. A new workstation needs an entry in the zone policy and `ca01`'s firewall, or it works from `paw01`.

## Git over SSH

`git.example.com` resolves to `edge01` for HTTPS, while Forgejo's SSH is on `git01:2222`. One entry makes displayed clone URLs work. `HostKeyAlias` is required so ssh checks the host certificate's real principal.

```sshconfig
Host git.example.com
  HostName __SVC_NET__.12
  Port 2222
  User git
  HostKeyAlias git.example.com
```

```bash
ssh -T git.example.com
```

Forgejo greets you by username and exits 1, since there is no shell. There are no keys to lose: log in again and push.

## Automation credentials

`bin/ap` and `bin/tf` issue their own certificates, reused while more than 30 minutes remain.

| `LABSTACK_SSH` | `bin/ap` | `bin/tf` |
|---|---|---|
| unset | Certificate, then static key | Private agent; your agent if `ca01` cannot issue |
| `cert` | Certificate or stop | Certificate or stop |
| `static` | Static key only | Your agent |
| `breakglass` | Offline certificate | n/a |

## Admin tasks

**Add or remove a person:** see [Access lifecycle](../admin/access-lifecycle.md).

**Revoke a certificate now.** Find the serial and key ID, add them, and run the playbook. Every sshd reads the new KRL immediately.
```bash
ssh-keygen -L -f <certificate>
```
```yaml
# inventories/common/group_vars/all/ssh_ca.yml
ssh_ca_revoked:
  - "serial: 1234567890123456789"   # this certificate
  - "id: alice@example.com"         # every certificate with this key ID
```
```bash
bin/ap prod playbooks/ssh-ca.yml
```

**See what was issued.** Each signing is a JSON line:
```bash
ssh ansible@ca01 sudo journalctl -u step-ca -u step-ca-login --since today -o cat | jq -c 'select(.status == 201 and (.path == "/ssh/sign" or .path == "/sign")) | {time, path, principals, subject, serial, from: ."remote-address", until: ."valid-to"}'
```

**Check host certificate expiry across the fleet:**
```bash
bin/ssh-cert prod ansible
```
```bash
cd ansible && ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/labstack/prod/ansible ansible -i inventories/common -i inventories/prod 'pve_nodes:service_guests' -b -o -m shell -a "ssh-keygen -L -f /etc/ssh/ssh_host_ed25519_key-cert.pub | sed -n 's/^ *Valid: from .* to //p'"
```

**Issue a TLS certificate by hand** for a name in the inventory or under `*.example.com` (policy refuses others):
```bash
step ca certificate git01.example.com git01.crt git01.key --san git01.example.com --provisioner hosts --not-after 720h --provisioner-password-file <(sops decrypt --extract '["provisioners"]["hosts"]["password"]' secrets/ca-prod.enc.yaml) --ca-url "$PLATFORM_CA_URL" --root "$PLATFORM_CA_ROOT"
```

**Rotate a provisioner:**
```bash
bin/ca-rotate-provisioner prod ansible
```
```bash
bin/ap prod playbooks/platform.yml --limit step_ca
```

**Enable ACME:** set `step_ca_acme_enabled: true` and run the play. Each client also needs a path to `ca01:443`, `ca01` must be able to reach the client for the challenge, and the client must trust the root.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Permission denied (publickey)` with a valid certificate | Principal not listed | Check `/etc/ssh/auth_principals/<account>` and `ssh_ca_people` |
| `Certificate invalid: expired` | Lifetime over | Log in again |
| `revoked by file` in host log | In `ssh_ca_revoked` | Remove if a mistake; run `ssh-ca.yml` |
| `Too many authentication failures` | Agent offers many keys | `-o IdentitiesOnly=yes -i <key>` |
| Fingerprint prompt or `HOST IDENTIFICATION HAS CHANGED` | No `@cert-authority` line, or host certificate expired | Fix `known_hosts`; run `ssh-ca.yml` |
| Login opens browser, then nothing | Callback cannot reach `127.0.0.1:10000` | Port forward |
| 403 or invalid group | Not in `ssh-admins` or `forgejo-users` | Authentik group |
| `step-ca-login` not answering | Authentik unreachable from `ca01` | `journalctl -u step-ca-login`; zone policy; `/etc/hosts` pin |
| `dns name not allowed` when signing | Name not in inventory | Add it, run the `step_ca` play |

## Roadmap

In rough order of value for effort:

1. Internal TLS everywhere: backend certificates, with Caddy verifying upstream.
2. Retire `roles/host_tls` on `bao01`; `pg01` keeps its own CA because `ca01` needs `pg01`.
3. People into OpenBao through Authentik, then revoke the root token.
4. Group-driven accounts: read `ssh-admins` from the Authentik API instead of a list.
5. Role principals from groups, scoping access per host.
6. Trust from first boot through cloud-init, eliminating static keys for VMs.
7. Hardware-backed root key, rotating the root because git history has the encrypted copy.
8. Issuance alerts in the SIEM.
9. Agent enrollment with certificates.
10. Short-lived database credentials through OpenBao.
