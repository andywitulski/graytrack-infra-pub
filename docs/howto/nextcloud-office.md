# Enable Nextcloud Office

**Goal:** Install Nextcloud apps as code, and edit documents in Collabora Online on `cloud01`.

| Piece | Location |
|---|---|
| Apps | `nextcloud_apps` in `inventories/common/group_vars/nextcloud.yml` |
| Collabora | Container `collabora` in `/opt/nextcloud`, port 9980 |
| Edge | Caddy site `office`, public; admin console and metrics internal only |
| Firewall | `cloud01:9980` from `edge01` only, at both layers |
| Secret | `collabora_admin_pass` |

**How a document opens:** the browser asks Nextcloud, which returns an editor URL on `office.example.com`. Collabora fetches and saves through WOPI on `cloud.example.com`. Both names go through Caddy. Collabora accepts documents only from `cloud.example.com`, and Nextcloud accepts WOPI calls only from `collabora_wopi_allowlist`.

## Steps

1. **Secret.**
   ```bash
   bin/gen-service-secrets prod
   ```
2. **Firewalls.** Expect one rule on `cloud01`, and "Edge to Nextcloud" gaining 9980. Without this, Caddy returns 502.
   ```bash
   bin/tf prod plan && bin/tf prod apply
   ```
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml --check
   ```
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml
   ```
3. **Edge and local DNS first,** since Nextcloud reaches Collabora by name.
   ```bash
   bin/ap prod playbooks/services.yml --limit edge01
   ```
   ```bash
   bin/ap prod playbooks/unifi_dns.yml
   ```
4. **Nextcloud.** Runs `richdocuments:activate-config` on every run as a health check.
   ```bash
   bin/ap prod playbooks/services.yml --limit cloud01
   ```
5. **Public DNS:** add an `office` CNAME. Without it, documents open only from inside and on the VPN.

## Verify

```bash
curl -s https://office.example.com/hosting/discovery | head -c 200
```

Open a `.docx`: the editor loads in the page. From outside, `/browser/dist/admin/admin.html` returns 403.

## Maintain

| Task | Action |
|---|---|
| Add an app | Add its ID to `nextcloud_apps`; run the play |
| Remove an app | Remove it from the list, then `occ app:disable <id>`. The role never uninstalls |
| Update Collabora | Bump `collabora_version` |

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Unauthorized WOPI host" | `docker compose logs collabora` shows the address; add it to the allowlist |
| "Collabora Online server not reachable" | `cloud01` cannot reach `office` through Caddy; check step 3 |
| An app fails to install | It has no release for this Nextcloud version; remove it for now |
