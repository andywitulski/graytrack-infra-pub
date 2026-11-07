# ADR-0010: Wazuh as SIEM, FIM and vulnerability detection

| | |
|---|---|
| **Status** | Accepted |
| **Date** | Recorded retroactively 2026-11-05; first alert validated 2026-10-08 |
| **Controls** | NIST AU-2, AU-6, AU-9, AU-12, SI-4, SI-7, RA-5, CA-7 |

## Context

Compromise of a host must not erase the record of it. Logs from hypervisors, guests, the edge, identity and the
gateway need correlating, and custom rules must be testable.

## Decision drivers

- Open source, self-hosted, single-node deployment feasible.
- Combined log analysis, file integrity and vulnerability detection.
- Rules as code with automated tests.

## Options considered

| Option | Assessment |
|---|---|
| Central syslog alone | Storage, not detection |
| ELK or Graylog | Flexible; detection content must be built from nothing |
| Wazuh | Agents, FIM, SCA, vulnerability detection, framework tags in rules |
| Commercial SIEM | Cost, and data leaves the environment |

## Decision

**Wazuh** on `siem01` in the Security zone. Custom decoders and rules live in `roles/wazuh_manager`. Every
deployment validates with `wazuh-analysisd -t`, restores the previous files on failure, then replays
`wazuh_manager_logtest_samples` through `wazuh-logtest`. **A sample that misses its rule fails the run.**

| Rule range | Source |
|---|---|
| 100100-100108 | Caddy |
| 100200-100212 | Authentik |
| 100300-100310 | Gateway |
| 100402 | Automation account from an unexpected address |
| 100421-100423 | Guest firewall |
| 100431-100434 | Audit configuration tampering |
| 100450-100452 | SSH certificate, break-glass and standing-key logins |

Wazuh syscheck replaces AIDE, and agent log forwarding replaces rsyslog.

## Consequences

- **Positive:** Detection logic is regression-tested. Dashboard login uses SSO, with a local account for break-glass.
- **Negative:** The indexer is memory-hungry and shares `pve01` with core services.
- **Residual risks:** Single node, and its backup is on the same pool as other backups. Attackers with Wazuh access can see detections. `ca01` issuance logs are not yet shipped as a rule source. No external alert channel is configured in this repository, so alerts need a dashboard review ([daily tasks](../admin/daily-tasks.md)).

## Validation

[ATP-008](../atp/ATP-008-detection.md).

## Related

[Connect log sources](../howto/siem-sources.md), [Dashboard SSO](../howto/siem-sso.md)
