# Serve admin UIs with internal TLS

**Goal:** Replace self-signed certificates on admin interfaces with certificates from `ca01`, so that browser warnings stop being routine.

**Prerequisite:** [Certificate authority](certificate-authority.md).

| UI | Host and port | Code |
|---|---|---|
| Proxmox VE | Nodes, 8006 | `roles/admin_ui_tls` `pve.yml` |
| Proxmox Backup Server | `pbs01`, 8007 | `pbs.yml` |
| Wazuh dashboard | `siem01`, 443 | `wazuh.yml` |
| OpenBao | `bao01`, 8200 | `roles/openbao` (`openbao_tls_ca01`) |

The key is generated on the host and never leaves it. The host writes a CSR, the controller signs it with the `hosts` provisioner, and the chain goes back. Policy signs only inventory names, `*.example.com` and inventory addresses. Certificates last 90 days and renew within the last 30.

## Steps

1. **Trust the root once per machine.** On macOS:
   ```bash
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ansible/files/prod/ca01-root.pem
   ```
   Firefox needs `security.enterprise_roots.enabled`. `paw01` gets the root from `roles/paw`.
2. **Check the OpenTofu endpoint is one of the names.** The certificate replaces the one OpenTofu talks to on 8006.
   ```bash
   sops decrypt --extract '["PROXMOX_VE_ENDPOINT"]' secrets/prod.enc.env
   ```
3. **OpenBao.** It restarts once and unseals itself. Clients use `bao01-trust.pem`, containing the old CA and the root, so nothing breaks in between. Commit the bundle.
   ```bash
   bin/ap prod playbooks/platform.yml --limit bao01 --check --diff
   ```
   ```bash
   bin/ap prod playbooks/platform.yml --limit bao01
   ```
4. **Nodes, PBS, Wazuh.**
   ```bash
   bin/ap prod playbooks/admin-tls.yml --check --diff
   ```
   ```bash
   bin/ap prod playbooks/admin-tls.yml
   ```
   Nodes are done one at a time: the UI blinks, while guests and the cluster are unaffected. PBS moves the storage entry to the new fingerprint; skipping that would fail the next backup. Use the Wazuh dashboard by name, since SAML is bound to it.
5. **Lab node.**
   ```bash
   bin/ap labnode playbooks/admin-tls.yml
   ```
   ```bash
   bin/ap labnode playbooks/backups.yml
   ```

## Verify

Any HTTP status is fine. A certificate error names the UI still on a self-signed certificate.

```bash
for u in https://pve01:8006 https://pbs01:8007 https://siem.example.com https://bao01:8200/v1/sys/health; do printf '%s  ' "$u"; curl -sS -o /dev/null -w '%{http_code}\n' --cacert ansible/files/prod/ca01-root.pem "$u"; done
```

## Renewal

`labstack-renew-certs.timer` on `paw01` runs `bin/renew-certs` every Monday around 04:30. It runs `admin-tls.yml` and `ssh-ca.yml` for prod and `labnode`, then the lab node's `backups.yml`. It uses what is checked out, only from a clean `main`, and never pulls. A failed run leaves the unit failed, which the patch run's health check and Wazuh see. The 30-day window covers a long absence, and `Persistent=true` catches up.

```bash
ssh ansible@paw01 'systemctl list-timers labstack-renew-certs.timer; sudo journalctl -u labstack-renew-certs -n 50 --no-pager'
```

**Why not self-renewal on each host?** Every host would need a network path to `ca01`. Today no guest talks to the CA.

**Not covered:** the gateway UI, which keeps its own certificate, and services behind Caddy, which have public certificates.
