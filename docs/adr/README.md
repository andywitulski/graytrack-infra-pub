# Architecture decision records

ADRs record decisions that are expensive to reverse: the context, the options weighed, the choice, and
its consequences. They are immutable once accepted. A later change gets a new ADR, or a dated update section
when the decision stands but rollout taught something.

| ADR | Decision | Status | Controls |
|---|---|---|---|
| [0001](0001-opentofu-over-terraform.md) | OpenTofu instead of Terraform | Accepted | CM-2, SC-28 |
| [0002](0002-tofu-state-in-postgresql.md) | OpenTofu state in PostgreSQL | Accepted | CP-9, SC-28 |
| [0003](0003-openbao-for-secrets.md) | OpenBao for secrets, sops/age as tier 0 | Accepted | IA-5, AU-2, SC-12 |
| [0004](0004-step-ca-for-certificates.md) | step-ca for X.509 and SSH certificates | Accepted | IA-2, IA-5, SC-17 |
| [0005](0005-lab-node-and-paw.md) | Standalone lab node and admin workstation | Accepted | AC-6, SC-7, CM-4 |
| [0006](0006-tpm-and-device-trust.md) | TPMs for machines, devices as a factor | Accepted, staged | IA-3, IA-2, SC-12 |
| [0007](0007-zone-segmentation-and-guest-firewalls.md) | Zone policy and hypervisor-enforced firewalls | Accepted, staged | SC-7, AC-4 |
| [0008](0008-single-edge-and-central-identity.md) | One inbound path and central identity | Accepted | AC-3, AC-17, IA-2 |
| [0009](0009-split-tunnel-overlay-vpn.md) | Split-tunnel overlay VPN | Accepted | AC-17, AC-19 |
| [0010](0010-wazuh-as-siem.md) | Wazuh as SIEM and FIM | Accepted | AU-6, SI-4, RA-5 |
| [0011](0011-backup-strategy.md) | Backup with PBS, ZFS snapshots and git mirrors | Accepted, gaps open | CP-9, CP-10 |
| [0012](0012-fleet-for-mobile-device-management.md) | Fleet for Apple MDM | Accepted | CM-8, AC-19 |
| [0013](0013-mail-hub-and-public-edge.md) | Internal mail hub, public edge deferred | Accepted, stage 2 proposed | SC-8, SC-28 |

ADRs 0001-0006 were recorded when decided. ADRs 0007-0013 were written retroactively from design notes and
code on 2026-11-05, so each carries the note "Recorded retroactively".

**Template:** Status, Date, Context, Decision drivers, Options considered, Decision, Consequences (positive,
negative, residual risk), Validation, Related.
