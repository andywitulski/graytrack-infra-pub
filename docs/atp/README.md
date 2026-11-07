# Acceptance test procedures

An ATP proves a control works, with defined steps, expected results and evidence. Run the relevant ATP after building or materially changing a component, and the full suite quarterly.

| ATP | Scope | Tests | Main controls |
|---|---|---|---|
| [ATP-001](ATP-001-platform-tier.md) | State backend and platform | 5 | CP-9, SC-8, SC-28 |
| [ATP-002](ATP-002-secrets.md) | Secrets | 6 | IA-5, AC-6, AU-2 |
| [ATP-003](ATP-003-certificates-and-ssh.md) | Certificates and SSH | 8 | IA-2, IA-5, AC-2 |
| [ATP-004](ATP-004-segmentation.md) | Segmentation | 7 | SC-7, AC-4 |
| [ATP-005](ATP-005-device-trust.md) | TPM and device trust | 6 | IA-3, IA-2 |
| [ATP-006](ATP-006-edge-and-identity.md) | Edge and identity | 8 | AC-3, AC-7, IA-2 |
| [ATP-007](ATP-007-remote-access.md) | Remote access | 6 | AC-17, AC-19 |
| [ATP-008](ATP-008-detection.md) | Detection and logging | 7 | AU-6, SI-4, RA-5 |
| [ATP-009](ATP-009-backup-restore.md) | Backup and restore | 6 | CP-9, CP-10 |
| [ATP-010](ATP-010-endpoint-management.md) | Endpoint management | 4 | CM-8, AC-19 |
| [ATP-011](ATP-011-applications.md) | Applications | 6 | AC-3, SC-8 |
| [ATP-012](ATP-012-baseline-and-supply-chain.md) | Baseline and supply chain | 6 | CM-6, SR-3, SI-2 |

## How to run

1. Note the date, tester, environment and commit (`git rev-parse HEAD`).
2. Run each test. Prefer `dev` where the feature exists. Destructive tests say so.
3. Record **Pass**, **Fail**, or **N/A** with a reason, and save output to [evidence](../evidence/README.md).
4. For a Fail, open an issue and update the [control status](../compliance/README.md).

**Status tags** on each test show what passing needs today:

| Tag | Meaning |
|---|---|
| (none) | Should pass as configured |
| `after-enforce` | Passes only after a staged switch is turned on. Expected result in this repository's state is listed |
| `drill` | Changes state; schedule it |

Results in this repository are templates. No claim is made that these have passed in your environment.

## Sign-off record

```text
ATP / version:       Date:       Tester:
Environment:         Commit:
Results:             T1 __  T2 __  T3 __ ...
Deviations:
Accepted by:
```
