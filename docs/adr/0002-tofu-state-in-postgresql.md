# ADR-0002: OpenTofu state in PostgreSQL on the cluster

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-10-28 |
| **Controls** | NIST CP-9, CP-10, SC-8, SC-28, AC-3 |

## Context

Every root kept its state as a local file on the controller. When that controller was wiped, the state of
every root went with it although the infrastructure kept running. Each resource had to be imported again
before any root could be planned safely.

## Decision drivers

- State must survive the loss of any one machine.
- Concurrent runs must be locked out.
- State must remain encrypted at rest.
- It must work offline, with no cloud account.

## Options considered

| Option | Assessment |
|---|---|
| Local files, backed up by hand | This is what failed. Relies on discipline, no locking across machines |
| Commit encrypted state to git | Durable, but one leaked passphrase exposes every past version forever; no locking |
| S3-compatible storage on the cluster (Garage, MinIO) | Lock support could not be confirmed for Garage; MinIO community edition is in maintenance mode; another storage system to run |
| PostgreSQL (`pg` backend) | Advisory locks, one schema per root, standard dump tooling, can also hold OpenBao's storage |

## Decision

Run **PostgreSQL on `pg01`** in its own root, `tofu/platform/<env>`, with database `tofu_state` and one schema
per root.

- Clients connect over TLS 1.3 with `sslmode=verify-full` against a pinned per-host CA.
- Role `tofu` authenticates with a SCRAM password from sops, from controller addresses only (`pg_hba` and the guest firewall).
- OpenTofu's client-side encryption stays on, so the database holds only ciphertext.
- `pg01` lives outside `tofu/envs/<env>`, so a bad plan there cannot destroy the database its own state is in. The platform root is bootstrapped on local state and then migrated.

## Consequences

- **Positive:** A wiped controller costs nothing: restore the age key, clone, run. One stateful service instead of two. The `pg` backend transfers directly to Terraform.
- **Negative:** `pg01` is now critical. If it is down, no root can plan or apply.
- **Mitigations:** Nightly `pg_dump` at 01:30, PBS backup at 02:00, Proxmox protection flag, and placement on `pve02`, not the storage node, so one failure never takes the database and its backups together.
- **Residual risk:** The platform root must be re-imported by hand if `pg01` and all its backups are lost. It is small.

## Validation

[ATP-001](../atp/ATP-001-platform-tier.md); the quarterly restore drill in [Periodic tasks](../admin/periodic-tasks.md).

## Related

[ADR-0001](0001-opentofu-over-terraform.md), [ADR-0003](0003-openbao-for-secrets.md), [Build the platform tier](../howto/platform-tier.md)
