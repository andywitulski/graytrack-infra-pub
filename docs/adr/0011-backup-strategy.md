# ADR-0011: Backup with PBS, ZFS snapshots and git mirrors

| | |
|---|---|
| **Status** | Accepted; offsite stage open |
| **Date** | Recorded retroactively 2026-11-05 |
| **Controls** | NIST CP-2, CP-4, CP-9, CP-9(1), CP-10, SC-28; CIS Control 11 |

## Context

Different data has different recovery needs. Guest disks need point-in-time restore, large file datasets need
protection from mistakes, and code must survive loss of the site.

## Decision drivers

- Client-side encryption, so backup storage cannot read data.
- Separate credentials per environment, with no ability to delete others' backups.
- Recovery must not depend on the failed tier.

## Options considered

| Option | Assessment |
|---|---|
| `vzdump` to NFS | Simple; no deduplication or client-side encryption |
| Proxmox Backup Server | Deduplication, encryption on the node, verify and prune jobs |
| Cloud object storage | Offsite, but cost for bulk data and a dependency |

## Decision

| Data | Mechanism | Copies |
|---|---|---|
| Guest disks | PBS nightly 02:00; keep 7 daily, 4 weekly, 6 monthly; encrypted on the node; verify job | 1, on `pve03` |
| PostgreSQL | `pg_dump` 01:30 inside the guest, then in its PBS backup | Same |
| Code, inventory, encrypted tier 0 | Git: Forgejo and a remote mirror | 2, 1 offsite |
| All Forgejo repositories | Push mirrors to a private GitHub organization | 2, 1 offsite |
| `tank` datasets | sanoid snapshots in the same pool | **1** |

The encryption key is held in sops and on paper, tied to the recovery kit. `labnode` backs up with its own token,
which can neither read nor prune the cluster's backups.

## Consequences

- **Positive:** Mistakes are recoverable in minutes. Code survives site loss.
- **Negative:** A circular dependency exists when `pve02` is lost. `pbs01` hosts backups but is not in them, and rebuilding it needs state in `pg01`. The [DR runbook](../runbooks/disaster-recovery.md) breaks this with a temporary PBS on `pve03`.
- **Residual risk (material):** The datastore is in the same pool as the data. A fire, theft or pool loss takes guest backups, and `tank` datasets have no backup at all. This fails the 3-2-1 rule. **Planned fix:** an offsite NAS with PBS sync and ZFS replication.
- **Note:** Mirrors replicate deletions and force pushes within hours. They protect against site loss, not mistakes.

## Validation

[ATP-009](../atp/ATP-009-backup-restore.md).

## Related

[Configure backups](../howto/backups-pbs.md), [Git mirrors](../howto/git-mirrors.md)
