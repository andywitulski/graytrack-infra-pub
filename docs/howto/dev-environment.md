# Build the dev environment

**Goal:** Build a scaled-down copy of prod on a nested Proxmox cluster, to prove changes before production.

Dev runs the same roles, inventory groups and identity module as prod. Its nodes are VMs from `tofu/envs/labnode`. **Run every command on `paw01`,** the only machine with a leg on the dev network (`__DEV_NET__.0/24`).

**Test a version bump:** set it in `inventories/dev/group_vars/<role>.yml`, run dev, then move the value to `inventories/common` and delete the override.

## What dev does not have

- No VLANs or gateway firewall: firewall rules are tested only in prod.
- No iGPU transcoding or AI host.
- Certificates are real Let's Encrypt certificates for `*.dev.example.com` over DNS-01. Let's Encrypt allows 5 identical certificates per week, so keep `caddy_data` or use the staging endpoint for frequent rebuilds.

## Addresses

| Host | Address | VMID | Node |
|---|---|---|---|
| `pvedev1`-`3` | `__DEV_NET__.11`-`13`; storage `__DEV_STOR_NET__.11`-`13` | | |
| `siem01`, `edge01`, `idp01`, `git01` | `.40`-`.43` | 1001, 1101, 1111, 1121 | `pvedev1` |
| `cloud01`, `pbs01` | `.44`, `.46` | 1131, 1151 | `pvedev2` |
| `media01`, `sync01`, `files01` | `.50`-`.52` | 1201, 1211, 1221 | `pvedev3` |
| `pg01`, `bao01`, `ca01` | `.60`-`.62` | 1301, 1311, 1321 | |

## Build

1. **Secrets.** Copy DNS credentials from prod without displaying them.
   ```bash
   bin/gen-service-secrets dev
   ```
   ```bash
   for k in caddy_dns_user caddy_dns_api_token; do V=$(sops decrypt --extract "[\"$k\"]" ansible/inventories/prod/group_vars/all/secrets.sops.yml); sops set ansible/inventories/dev/group_vars/all/secrets.sops.yml "[\"$k\"]" "\"$V\""; unset V; done
   ```
2. **Nested cluster.** First [create the nodes](lab-node.md#6-dev-cluster).
   ```bash
   bin/ap dev playbooks/bootstrap.yml -e ansible_user=root
   ```
   ```bash
   bin/ap dev playbooks/network.yml
   ```
   ```bash
   (cd ansible && ansible pve_nodes -b -m ansible.builtin.reboot)
   ```
   ```bash
   bin/ap dev playbooks/pve-cluster.yml
   ```
   ```bash
   bin/ap dev playbooks/telemetry-baseline.yml
   ```
   ```bash
   bin/ap dev playbooks/storage.yml
   ```
3. **OpenTofu API.** Trust the new cluster's CA and put a new token in `secrets/dev.enc.env`. `PROXMOX_VE_ENDPOINT` stays on `pvedev1`.
4. **Guests.** The outposts restart in a loop until step 5 gives them tokens. That is expected.
   ```bash
   bin/tf dev init -upgrade && bin/tf dev apply
   ```
   ```bash
   bin/ap dev playbooks/lxc_host.yml
   ```
   ```bash
   bin/ap dev playbooks/services.yml --limit lxc_guests -e ansible_user=root
   ```
   ```bash
   bin/ap dev playbooks/services.yml
   ```
5. **Identity and issued secrets.** Dev has no OpenBao, so outputs go to sops.
   ```bash
   bin/tf-ak dev init -upgrade && bin/tf-ak dev apply
   ```
   Copy `${k}_client_secret` for each OIDC application and `jellyfin_ldap_bind_password` into dev's sops file. Save `ldap_ca_pem` to `ansible/files/dev/`. Fetch outpost tokens from the Authentik API (`/api/v3/core/tokens/ak-outpost-<id>-api/view_key/`) into `authentik_<o>_outpost_token`. Then run services again.
6. **Backups.** Follow [Configure backups](backups-pbs.md) with `dev`.

## Tear down

This destroys the nodes and every dev guest. Dev's state lived in dev's own `pg01`, so it goes too. Sops secrets are kept. The token, CA and identity objects must be recreated.

```bash
bin/tf labnode apply -var build_dev=false
```
