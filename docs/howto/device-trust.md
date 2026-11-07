# Roll out device trust

**Goal:** Add vTPMs to VMs, pin their identity, seal secrets to a host, and make registered devices a sign-in factor.

**Why, and what it does not cover:** [ADR-0006](../adr/0006-tpm-and-device-trust.md). **Accept with:** [ATP-005](../atp/ATP-005-device-trust.md).

| Piece | Location | Switch |
|---|---|---|
| vTPM | `tofu/modules/service_vm` (`vtpm`) | Applied one VM at a time |
| EK pins | `roles/tpm`, `playbooks/tpm.yml` | Runs on `tpm_hosts` |
| Sealed credentials | `roles/tpm` `tasks/seal.yml` | Per service |
| Device certificates | `roles/step_ca`, `bin/device-cert` | `device_trust_mode`, `device_trust` |
| Sign-in factor | `tofu/modules/authentik_config/device_trust.tf`, `roles/caddy` | Same |

`device_trust_mode` (Ansible) and `device_trust` (OpenTofu) are one switch in two places. Keep them equal.

## 1. Add vTPMs

Adding a TPM stops and starts the VM. Go one at a time, least critical first, checking each. If a plan shows a VM replaced, **stop**.

```bash
bin/tf prod plan -target='module.siem01'
```
```bash
bin/tf prod apply -target='module.siem01'
```

Then `pbs01`, `git01`, `cloud01`, `mdm01`, `pw01`, `edge01`, `idp01` with `-target='module.service_vm["<name>"]'`, then the lab node's guests. `edge01` and `idp01` cause a short outage. A plain `bin/tf prod plan` must then show no changes.

Record and pin. Every VM's pin should read `chain: verified`.

```bash
bin/ap prod playbooks/tpm.yml
```

| Message | Meaning | Action |
|---|---|---|
| The TPM changed | Rebuild, restore, or another host at that address | Investigate. If intended: `-e tpm_ek_accept_change=true --limit <host>` and commit the pin |
| Same EK as `<host>` | A clone | Remove `tpm_state`, apply, add it back, apply, re-pin |
| No `/dev/tpmrm0` | vTPM not applied or VM not restarted | Step 1 |
| Chain FAILED | EK does not chain to a recorded node CA | Check `issuer` in the pin |

## 2. Seal a secret to a host

For native systemd services, not Docker stacks.

```yaml
- name: Enrollment token, sealed to this host's TPM
  ansible.builtin.include_role:
    name: tpm
    tasks_from: seal
  vars:
    tpm_seal_name: example-app-enroll-token
    tpm_seal_value: "{{ example_app_enroll_token }}"
```
```ini
LoadCredentialEncrypted=example-app-enroll-token:/etc/credstore.encrypted/example-app-enroll-token
```

The service reads `$CREDENTIALS_DIRECTORY/example-app-enroll-token`. The same file copied to another VM does not open.

## 3. Enroll

Order matters: `step-ca-login` will not start while a discovery URL it lists does not exist.

1. Set `device_trust = "enroll"` in `tofu/authentik/prod/main.tf` and apply. Sign-in does not change.
   ```bash
   bin/tf-ak prod apply
   ```
2. Set `device_trust_mode: "enroll"`, then:
   ```bash
   bin/ap prod playbooks/platform.yml --limit step_ca
   ```
   ```bash
   bin/ap prod playbooks/services.yml --limit caddy
   ```
3. **Understand what counts.** Caddy asks the *browser that signs in* for a certificate, so a device counts only where its browser runs.

   | Device | State |
   |---|---|
   | macOS workstation | Secure Enclave unavailable to unsigned plugins; planned: YubiKey (PIV) |
   | `paw01` | Key in TPM, but no browser; planned: desktop PAW with `tpm2-pkcs11` |

4. Enroll. Sign in with your second factor, never the device itself. The output ends with a line for `trusted_devices`.
   ```bash
   bin/device-cert prod enroll alice@example.com
   ```
   On a host with SSH forwarding disabled, the browser fails to load the `http://127.0.0.1:10000/?code=...` callback. Copy that URL and, within a minute, run it through `curl` in a second session on the host.

## 4. Enforce

Stop unless all of these are true:

- [ ] `firewall_enforce = true` is applied. Otherwise anyone reaching `idp01:9000` around Caddy could send the header.
- [ ] A registered device with a browser presents its certificate and signs in. Otherwise you lock yourself out of Proxmox, Wazuh, Fleet and SSH certificates.
- [ ] A second factor still works, and you know the recovery path.

Set both switches to `enforce` and apply.

## Back out

Set `device_trust = "enroll"` and apply `bin/tf-ak prod apply`. The second factor applies everywhere again.

## Day to day

| Task | Action |
|---|---|
| Renew (30 days) | Re-run `bin/device-cert prod enroll`. Same key, so the registration stays |
| Lost device | Delete its `trusted_devices` line and apply. It stops counting at once |
| New device | Enroll and register its hash |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Could not create the key (Linux) | Not yet in group `tss` | Log out and in |
| `step-ca-login` down after the play | `step-ca-device` missing in Authentik | Apply with `enroll`; restart |
| Browser never offers the certificate | No identity in keychain | Re-enroll |
| Handshake fails on `auth` | Offered certificate does not chain to `ca01` | Choose the right identity, or none |
| Device present but asked for MFA | Hash not registered or under another user | `bin/device-cert prod status`; `idp01` log shows `presented=` |
