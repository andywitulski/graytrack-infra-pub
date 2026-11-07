# Patching

| What | How | When |
|---|---|---|
| Debian security updates on guests | `unattended-upgrades`; `needrestart` restarts services | Daily, automatic |
| All other repositories, nodes, kernels, reboots | `playbooks/patch.yml` | Weekly, or after a backup night |
| Application versions | Bump the pin, then `services.yml` | Per release, on purpose: they migrate databases |

## Run

Review first, then upgrade, and reboot only when you choose to.

```bash
bin/ap prod playbooks/patch.yml --check
```
```bash
bin/ap prod playbooks/patch.yml
```
```bash
bin/ap prod playbooks/patch.yml -e patch_reboot=true
```
```bash
bin/ap prod playbooks/patch.yml --limit pve02 -e patch_reboot=true
```

The same works for `labnode` and `dev`. The last task prints one line per host: packages upgraded, reboot state, kernel, held packages, outdated services.

## What it does per host

1. **Installs `needrestart`.** Guests restart outdated services. Nodes only list them. Docker and containerd are never restarted automatically, because that would restart every container.
2. **Full upgrade,** never plain `apt upgrade`: Proxmox supports only full-upgrade. Changed config files are kept, and held packages stay held.
3. **Decides whether a reboot is needed.** LXCs never need one.
4. **Reboots** with `patch_reboot=true` only, one host at a time.
5. **Checks health, always:** no newly failed systemd units, plus the following.

   | Host | Check |
   |---|---|
   | `pg01`, `gpu01` | PostgreSQL accepts connections |
   | `bao01` | Unsealed and active |
   | `ca01` | Answers on 443 and 8443 |
   | Docker hosts | No container unhealthy or restarting |
   | Nodes | Services up, quorate, on-boot guests started |

**Any failure stops the run before the next host,** so a bad update stays on one host.

## Order and impact

Service guests go first (5 at a time, or 1 when rebooting), then `pg01`, `bao01`, `ca01` one at a time, then nodes one at a time.

A node reboot restarts every guest on it (local storage, no HA). `pve03` also interrupts its NFS clients. **Reboot nodes in a quiet hour, never across the 02:00 backup window.**

A controller is protected from cutting off its own run. From `paw01`, neither `paw01` nor `labnode` reboots; the summary says "needed (runs this controller)". Reboot those from the workstation:

```bash
bin/ap labnode playbooks/patch.yml --limit labnode,paw01 -e patch_reboot=true
```

## Update an application

Everything is pinned to an exact version, because stacks pull only missing tags: a floating tag never moves once it is on the host.

1. Change the pin and read the release notes.
2. For Authentik, Forgejo and Nextcloud, take a fresh dump if the last is old, since they migrate on start.
3. Check, then apply. A tag that does not exist fails at the pull, and running containers stay.
   ```bash
   bin/ap prod playbooks/services.yml --limit <host> --check --diff
   ```

| Pin | File | Host |
|---|---|---|
| `authentik_version` | `inventories/common/group_vars/authentik.yml` | `idp01` |
| `forgejo_version` | `.../forgejo.yml` | `git01` |
| `nextcloud_version`, `collabora_version` | `.../nextcloud.yml` | `cloud01` |
| `caddy_version` | `roles/caddy/defaults/main.yml` | `edge01` |
| `ollama_version` | `.../ollama.yml` | `gpu01` |
| `media_navidrome_version` | `.../media.yml` | `media01` |
| `vaultwarden_version` | `.../vaultwarden.yml` | `pw01` |
| `fleet_version` | `.../fleet.yml` | `mdm01` |
| `headscale_version` and checksum | `.../headscale.yml` | `hs01` |
| Postgres, Redis images | `roles/*/templates/compose.yml.j2` | Application hosts |
| `openbao_version`, `step_ca_version`, `step_cli_version` and checksums | Role defaults, `all/ssh_ca.yml` | `bao01`, `ca01`, `paw01` |
| `wazuh_manager_version`, `wazuh_agent_version` | Role defaults, always together; follow Wazuh's upgrade guide | `siem01`, all agents |

PostgreSQL in containers stays on major 16. A major upgrade needs a dump and restore.

## Renovate

Renovate reads `# renovate:` comments and opens one pull request per update, with release notes. It also covers OpenTofu providers, `mise.toml` and pre-commit hooks. Security updates get a label and skip the weekly schedule. **It changes nothing by itself.**

For checksummed downloads the pull request bumps only the version. Update `*_sha256` from the release's checksums in the same PR; the play refuses a mismatch.

## Afterward

- Renew admin certificates in the same session ([guide](../howto/admin-ui-tls.md#renewal)).
- In Wazuh Vulnerability Detection, outstanding CVEs should drop. What remains is held, pinned, or unfixed.
- `patch_autoremove=true` removes old kernels and orphans. Check first with `apt-get -s autoremove`.
