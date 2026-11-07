# Configure backups

**Goal:** Back up every guest nightly to Proxmox Backup Server with client-side encryption, and secure the encryption key the same day.

**Why:** [ADR-0011](../adr/0011-backup-strategy.md). **Accept with:** [ATP-009](../atp/ATP-009-backup-restore.md). **Restore:** [Disaster recovery](../runbooks/disaster-recovery.md).

`playbooks/backups.yml` covers both sides:

- **PBS:** datastore on NFS, user `pve@pbs` with token `cluster` limited to DatastoreBackup on one datastore, GC, prune and verify jobs.
- **Cluster:** the storage entry and a nightly job for every guest except PBS itself.

Jobs are created only when none of that kind exist, so hand-made jobs are left alone. The certificate fingerprint is read live on every run.

## First run

The play stops at "Token secret is stored". The new token is on PBS.

```bash
bin/ap prod playbooks/backups.yml
```
```bash
ssh ansible@pbs01 'sudo jq -r .value /root/pbs-cluster-token.json' | bin/bao-secret prod set pbs_cluster_token_secret
```
```bash
ssh ansible@pbs01 sudo rm /root/pbs-cluster-token.json
```
```bash
bin/ap prod playbooks/backups.yml
```

## Save the encryption key the same day

While `pbs_encryption_key` is PENDING, the storage is created with a new key on the cluster. **Without that key the backups cannot be read.** Keep two copies off the cluster:

```bash
V=$(ssh ansible@<node> sudo cat /etc/pve/priv/storage/pbs01.enc | jq -c .)
sops set ansible/inventories/prod/group_vars/all/secrets.sops.yml '["pbs_encryption_key"]' "$(jq -Rn --arg v "$V" '$v')"; unset V
```
```bash
ssh ansible@<node> sudo proxmox-backup-client key paperkey /etc/pve/priv/storage/pbs01.enc --output-format text
```

Print the paper key and store it with the recovery kit. A rebuilt cluster gets the same key from sops and can read old backups.

## Verify

```bash
ssh ansible@<node> sudo pvesm status --storage pbs01
```
```bash
ssh ansible@<node> sudo pvesh get /cluster/backup
```
```bash
ssh ansible@pbs01 sudo proxmox-backup-manager prune-job list
```
```bash
ssh ansible@pbs01 sudo proxmox-backup-manager verify-job list
```

**A backup is proven only by a restore.** See [ATP-009](../atp/ATP-009-backup-restore.md).

## Lab node

`labnode` uses its own token `pve@pbs!labnode` (`pbs_extra_tokens`), so it can neither read nor prune the cluster's backups. It has its own encryption key and backs up only the IDs in `pbs_remote.vmids`. See [Build the lab node](lab-node.md#10-agents-and-backups).
