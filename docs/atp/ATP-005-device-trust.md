# ATP-005: TPM and device trust

**Objective:** Prove machine identity pins and device-based sign-in.
**Prerequisites:** [Device trust](../howto/device-trust.md). `device_trust` is at `enroll` in this repository.

| ID | Test | Steps | Expected | Tag |
|---|---|---|---|---|
| T1 | EK pins verified | `bin/ap prod playbooks/tpm.yml` | Every VM reads `chain: verified` | |
| T2 | Clone detected | Clone a test VM with its vTPM into the inventory; run the play | Stops: "same EK as `<host>`" | `drill` |
| T3 | Sealed credential does not travel | Copy a sealed file to another VM; try `systemd-creds decrypt` | Fails | `drill` |
| T4 | Trusted device, everyday application | Sign in to Nextcloud with a registered device | Password only | `after-enforce` |
| T5 | Untrusted device | Sign in from a phone: Nextcloud, then the Proxmox UI | Password and second factor; admin application refused | `after-enforce` |
| T6 | Device removal is immediate | Delete a `trusted_devices` line, apply, sign in with the valid certificate | Treated as untrusted | `after-enforce` |

**Also check after enforce:** `idp01:9000` answers only `edge01`, and `docker compose logs server | grep 'device check'` shows `trusted=true` for the device.
