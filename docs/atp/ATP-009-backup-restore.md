# ATP-009: Backup and restore

**Objective:** Prove backups are complete, encrypted and restorable. A backup counts only once restored.

**Caution:** Restore to a spare VMID on an isolated bridge with NICs disconnected. A duplicate guest on the network clashes with the original.

| ID | Test | Steps | Expected | Tag |
|---|---|---|---|---|
| T1 | Job coverage | `ssh ansible@<node> sudo pvesh get /cluster/backup` against the inventory | Every guest except `pbs01` | |
| T2 | Verify jobs pass | `ssh ansible@pbs01 sudo proxmox-backup-manager verify-job list`; check last results | Recent, OK | |
| T3 | Restore the state database | Restore `pg01` to a spare VMID; start isolated; `pg_restore --list` the newest dump; delete | Dump is readable, and recent | `drill` |
| T4 | Restore a service | Restore one VM to a spare VMID; boot isolated; check the application; delete | Application starts with its data | `drill` |
| T5 | Encryption and key custody | On PBS, confirm chunks are encrypted; decrypt `pbs_encryption_key` with the **offline** age key | Encrypted; key available | `drill` |
| T6 | Credential isolation | With the `labnode` token, try to list or prune the cluster's backups | Permission denied | |

**Known failures to record:** no copy off-site, and `tank` datasets have no backup ([ADR-0011](../adr/0011-backup-strategy.md)). Record RTO achieved against [targets](../runbooks/disaster-recovery.md).
