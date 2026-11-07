# Disaster recovery

How to get the platform back, by what broke, and the order everything comes up in. **Read [Gaps](#gaps) first:** they decide what a disaster costs today.

| Objective | Target | Basis |
|---|---|---|
| RPO, guests | 24 h | Nightly PBS at 02:00 |
| RPO, code | Last push | Forgejo and mirrors |
| RPO, bulk data | Hourly to daily for mistakes; **no protection from pool loss** | sanoid |
| RTO, single guest | Under 1 h | Restore plus play |
| RTO, platform tier | Under 4 h | Scenario B |

These are planning targets. Confirm them with [drills](#drills).

## Recovery kit

Without these, nothing below works. Keep them away from the site, and check them twice a year.

| Item | Why | Where |
|---|---|---|
| age key | Decrypts all sops files | Two controllers and **two offline copies**, one off-site |
| PBS encryption key | Reads backups | sops and a paper key |
| OpenBao recovery keys | `generate-root` | sops and paper |
| GitHub account and recovery codes | Repositories and backup org | Password manager and printed codes |
| Gateway account and backup | Network config not in playbooks | Cloud backup and a downloaded `.unf` |
| DNS provider account | Public DNS, DNS-01 certificates | Password manager |
| Apple Account of the MDM push certificate | Yearly renewal; another account forces re-enrollment | Password manager and recovery codes |
| Bootstrap SSH key | First runs on fresh hosts | Controllers and an offline copy |

## What runs where

| Node | Guests | Node-local data |
|---|---|---|
| `pve01` | `edge01` 4101, `idp01` 4111, `git01` 4121, `pw01` 4161, `mdm01` 4171, `siem01` 4001 | Guest disks |
| `pve02` | `pg01` 4301, `bao01` 4311, `ca01` 4321, `cloud01` 4131, `pbs01` 4151, `ai01` 4141 | Guest disks |
| `pve03` | `media01` 4201, `sync01` 4211, `files01` 4221, `hs01` 4231, `ts01` 4241, `ts02` 4251, `mail01` 4261 | **Pool `tank`:** PBS datastore, Nextcloud files, shares, media |
| `labnode` | `paw01` 5001, `gpu01` 5011, `kali01` | Backs up to `pbs01` |

Dependencies are in [Architecture](../architecture/overview.md#layers).

## What a backup covers

| Data | Mechanism | Copies |
|---|---|---|
| Guest disks, including dumps inside them | PBS nightly; 7 daily, 4 weekly, 6 monthly | 1, on `pve03` |
| Code, inventory, encrypted secrets | Git | 2, 1 off-site |
| All Forgejo repositories | Push mirrors | 2, 1 off-site |
| `tank` datasets | sanoid in the same pool. **Bind mounts and NFS are not in guest backups** | **1** |
| Node configuration | Rebuilt by playbooks | Code only |

## Gaps

1. **Nothing but git leaves the site.** The datastore is in the same pool as the data it protects. Planned fix: off-site PBS sync and ZFS replication.
2. **`tank` datasets have no backup,** only same-pool snapshots.
3. **`pve03` is a single point** for bulk data and backups.
4. **AppRole secret IDs expire after 90 days,** and every `bin/ap` run needs OpenBao. Use cert login, and rotate before expiry.
5. **Restores must be exercised.** Run the [drills](#drills) and retain the evidence.

## Scenarios

Commands run on a controller from a clean `main`.

### A. One guest broken

List backups, then restore over the old guest with the same VMID. `pg01`, `bao01` and `ca01` have a protection flag: clear it first with `pct set <id> --protection 0`.

```bash
ssh ansible@pve02 'sudo pvesm list pbs01 --vmid <vmid>'
```
```bash
ssh ansible@<node> 'sudo qmrestore pbs01:backup/vm/<vmid>/<time> <vmid> --force 1 --storage local-lvm'
```
```bash
ssh ansible@<node> 'sudo pct restore <vmid> pbs01:backup/ct/<vmid>/<time> --force 1 --storage local-lvm'
```
```bash
ssh ansible@<node> 'sudo qm start <vmid>'
```
```bash
bin/ap prod playbooks/services.yml --limit <host>
```

Use `platform.yml` for platform guests. LXCs with bind mounts also need `bin/ap prod playbooks/lxc_host.yml --limit pve03`.

**No usable backup:** destroy, recreate with `bin/tf prod apply`, configure (`-e ansible_user=root` for a fresh LXC), then restore data from a file-level restore or the application's dump.

### B. Platform tier

Order is fixed: **`pg01`, then `bao01`, then `ca01`.** All three are on `pve02`.

| Guest | Recovery | While it is down |
|---|---|---|
| `pg01` | Restore (A). No backup: `bin/tf-platform prod bootstrap`, `platform.yml`, restore dumps, `bin/tf-platform prod migrate` | No root can plan; OpenBao retries; nothing is lost |
| `bao01` | Restore (A), or `bin/tf-platform prod apply` and `platform.yml --limit bao01`. Data is in `pg01` and the seal key in sops, so it unseals itself. Commit the new CA | Only `sops_only` playbooks: `LABSTACK_OPENBAO=off bin/ap ...` |
| `ca01` | Nothing unique on it: clear the flag, `bin/tf-platform prod apply`, `platform.yml --limit ca01 -e ansible_user=root`, `platform.yml` | Static key or break-glass |

Restore dumps in this order:

```bash
sudo -u postgres psql -f globals-STAMP.sql
```
```bash
sudo -u postgres pg_restore --clean --if-exists -d tofu_state tofu_state-STAMP.dump
```
```bash
sudo -u postgres pg_restore --clean --if-exists -d openbao openbao-STAMP.dump
```

**OpenBao sealed after start:** the key in sops does not match. Find the right one in the git history of the sops file. **Never re-initialize,** which requires an empty database.

**Root token needed:** `bao operator generate-root -init`, then `-recovery-key` with 3 of the 5 keys, and decode with the OTP.

### C. A node dies

Quorum holds with two nodes. The dead node's guests are down. Restore them to a surviving node (A), and move them back later.

| Node lost | What stops | Restore onto | Notes |
|---|---|---|---|
| `pve01` | Web names, sign-in, git, MDM, SIEM | `pve02`, memory permitting | `edge01` and `idp01` first; `siem01` last |
| `pve02` | Platform tier, Nextcloud, **`pbs01`**, AI | `pve01` or `pve03` | Below |
| `pve03`, disks intact | Bulk data, PBS datastore, remote access | New hardware | Install, `zpool import -f tank`, node steps, `storage.yml`, `lxc_host.yml` |
| `pve03`, pool lost | All bulk data and all guest backups | | **Unrecoverable today.** Take fresh backups to a new datastore at once |

**`pve02` lost: the circular dependency.** Restoring `pg01` needs `pbs01`; `pbs01` is on `pve02` and not in its own backups; rebuilding it needs state in `pg01`. Break the loop with a temporary PBS on `pve03`, which holds the datastore locally:

```bash
ssh ansible@pve03
```
```bash
echo 'deb http://download.proxmox.com/debian/pbs trixie pbs-no-subscription' | sudo tee /etc/apt/sources.list.d/pbs-dr.list
```
```bash
sudo apt-get update && sudo apt-get install -y proxmox-backup-server
```
```bash
sudo proxmox-backup-manager datastore create tank /tank/backups/pbs --reuse-datastore true
```
```bash
sudo proxmox-backup-manager cert info | grep -i fingerprint
```

From the controller, move the key without printing it, and add the storage:

```bash
sops decrypt --extract '["pbs_encryption_key"]' ansible/inventories/prod/group_vars/all/secrets.sops.yml | ssh ansible@pve01 'sudo install -m 0600 /dev/stdin /root/pbs-dr.enc'
```
```bash
ssh ansible@pve01 'sudo pvesm add pbs pbs-dr --server __MGMT_NET__.5 --datastore tank --username root@pam --password <root-password> --fingerprint <fingerprint> --encryption-key /root/pbs-dr.enc'
```

Restore `pg01`, `bao01` and `ca01` from `pbs-dr` onto `pve01`. Move `pbs01` to a surviving node in `tofu/envs/prod/services.tf`, apply, run `backups.yml`, and restore the rest. Finally `pvesm remove pbs-dr`, purge the package on `pve03` (the datastore stays), and delete `/root/pbs-dr.enc`.

**Replace a node (same name and address):**

```bash
ssh ansible@pve02 'sudo pvecm delnode pve01'
```
```bash
bin/ap prod playbooks/bootstrap.yml --limit pve01 -e ansible_user=root
```
```bash
bin/ap prod playbooks/network.yml --limit pve01
```
```bash
bin/ap prod playbooks/pve-cluster.yml
```
```bash
bin/ap prod playbooks/telemetry-baseline.yml --limit pve01
```
```bash
bin/ap prod playbooks/ssh-ca.yml --limit pve01
```

### D. Controller lost

`paw01` is a full second controller. From a new machine: restore the age key (0600) and bootstrap key from the offline copy, clone, install tools (`mise install`), then:

```bash
sops decrypt --extract '["secrets_file_version"]' ansible/inventories/prod/group_vars/all/secrets.sops.yml
```
```bash
bin/ap prod playbooks/openbao-smoke.yml
```

A new machine on another address cannot reach the platform until `unifi_firewall.yml` runs with that address. Run it from `paw01`, or reuse the old address. Compare the root fingerprint with your record.

### E. Gateway reset or replaced

1. Restore the newest console backup. That brings everything back.
2. Without one: set up WAN and an admin account by hand, create an API key, and store it with `sops set`. It is `sops_only`, so this works with OpenBao unreachable. Then:

```bash
LABSTACK_OPENBAO=off bin/ap prod playbooks/unifi_switching.yml
```
```bash
LABSTACK_OPENBAO=off bin/ap prod playbooks/unifi_firewall.yml
```
```bash
bin/ap prod playbooks/unifi_dns.yml
```

Guests use static addresses, so nothing else changes. Then redo the console-only [SIEM export](../howto/siem-sources.md#configure-the-gateway-one-time-console-only).

### F. Everything lost

**What exists afterward:** the mirrored repositories and the recovery kit.

**What does not:** PBS backups, OpenBao's secrets, OpenTofu state, Authentik's users and MFA enrollments, Nextcloud files, shares and media.

This is a fresh build with new secrets: follow the rebuild order below, with `bin/gen-service-secrets prod`, a new OpenBao and new CA keys. Then restore repositories ([procedure](../howto/git-mirrors.md#restore)). With an off-site NAS (Gap 1) this becomes a restore.

## Full rebuild order

Skip what still works. Restoring from PBS replaces "create and configure" for that guest.

| # | Step | Commands | Needs |
|---|---|---|---|
| 1 | Controller | D | Recovery kit |
| 2 | Network | E | Gateway backup or API key |
| 3 | Nodes | Install; `bootstrap.yml`, `network.yml`, reboot, `pve-cluster.yml`, `telemetry-baseline.yml` | 2 |
| 4 | Storage | `zpool import tank`, `storage.yml` | 3 |
| 5 | OpenTofu API | Trust the CA; new token in sops | 3 |
| 6 | Backups | `bin/tf prod apply -target='module.service_vm["pbs01"]'`, `backups.yml` | 4, 5 |
| 7 | Platform | Restore (B), or [fresh build](../howto/platform-tier.md) | 6 |
| 8 | State | Restored with `pg01`, or [adopt](../howto/platform-tier.md#move-other-roots-onto-the-backend) | 7 |
| 9 | Guests | Restore (A), or `bin/tf prod apply`, `lxc_host.yml`, `services.yml` | 7 |
| 10 | Edge and identity | `edge01`, `idp01`; `bin/tf-ak prod plan` shows no changes | 9 |
| 11 | Remote access | `hs01`, then `ts01`, `ts02` | 10 |
| 12 | Services | `pw01` first, `git01`, `mdm01` (**restore, never rebuild**), `mail01`, `cloud01`, `media01`, `files01`, `sync01`, `ai01` | 10 |
| 13 | Certificates | `ssh-ca.yml`, `admin-tls.yml` | 7 |
| 14 | SIEM | `siem01`, `services.yml --limit wazuh_agents` | 9 |
| 15 | Lab node | [Guide](../howto/lab-node.md); `paw01`, `gpu01` from PBS | 6 |
| 16 | Public | `unifi_dns.yml`, public DNS, `unifi_public_exposure` | 10 |

## Verify after any recovery

```bash
ssh ansible@pve01 'sudo pvecm status | grep -E "Quorate|Nodes"'
```
```bash
bin/ap prod playbooks/openbao-smoke.yml
```
```bash
bin/tf prod plan; bin/tf-platform prod plan; bin/tf-ak prod plan
```
```bash
bin/ap prod playbooks/services.yml --check --diff
```
```bash
bin/ap prod playbooks/patch.yml --check
```
```bash
ssh ansible@pve02 'sudo pvesh get /cluster/backup'
```

Plans and check runs should show no changes. Then run a fresh backup of everything, and record what happened ([incident record](incident-response.md#record)).

## Drills

| When | Drill |
|---|---|
| Quarterly | Restore `pg01` to a spare VMID on an isolated bridge, `pg_restore --list` the newest dump, delete it |
| Quarterly | Restore one service VM to a spare VMID, boot, check the application, delete |
| Twice a year | Recovery kit: decrypt with the offline age key; check GitHub recovery codes; download a gateway backup |
| Yearly | Scenario D on a spare machine, end to end |

See [ATP-009](../atp/ATP-009-backup-restore.md).
