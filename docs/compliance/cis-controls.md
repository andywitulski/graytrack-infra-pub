# CIS Critical Security Controls v8.1 mapping

| # | Control | Implementation | LC | Status |
|---|---|---|---|---|
| 1 | Inventory and Control of Enterprise Assets | Ansible inventories, OpenTofu, Fleet, zone policy | LC-27, LC-33 | Implemented |
| 2 | Inventory and Control of Software Assets | Pinned versions; Wazuh software inventory | LC-25, LC-31 | Implemented |
| 3 | Data Protection | Encrypted secrets, state and backups; live disks unencrypted | LC-17, LC-19, LC-34 | Partial (G-04) |
| 4 | Secure Configuration of Enterprise Assets and Software | CIS baseline, IaC, default-deny; containers unhardened | LC-27, LC-28 | Partial (G-05) |
| 5 | Account Management | Authentik, code-defined accounts, no passwords on guests | LC-10, LC-16 | Partial |
| 6 | Access Control Management | MFA, SSO, per-application groups, short-lived certificates | LC-07, LC-10, LC-11 | Implemented |
| 7 | Continuous Vulnerability Management | Wazuh, patch runs, Renovate | LC-25, LC-30, LC-31 | Implemented |
| 8 | Audit Log Management | Central collection, redaction, time sync | LC-22, LC-26 | Implemented |
| 9 | Email and Web Browser Protections | Providers filter mail; no public mail surface | | Partial |
| 10 | Malware Defenses | Rootcheck, FIM; no dedicated endpoint anti-malware | LC-24 | Partial |
| 11 | Data Recovery | PBS, dumps, snapshots, mirrors; no off-site guest backup | LC-34, LC-35, LC-36 | Partial (G-01) |
| 12 | Network Infrastructure Management | Gateway policy as code, read-back verification | LC-01, LC-27 | Implemented |
| 13 | Network Monitoring and Defense | Gateway logs, IPS events, firewall logs; no active blocking | LC-22, LC-23 | Partial (G-14) |
| 14 | Security Awareness and Skills Training | Guides; no program | | N/A at this scale |
| 15 | Service Provider Management | Few providers, each named in the recovery kit | | Partial |
| 16 | Application Software Security | Vendor applications; edge path controls; header gap | LC-04 | Partial (G-06) |
| 17 | Incident Response Management | IR runbook, not yet exercised | LC-36 | Partial (G-20) |
| 18 | Penetration Testing | Isolated test VM; no formal program | LC-05 | Gap (G-15) |

## Implementation Group view

| Group | Assessment |
|---|---|
| IG1, essential hygiene | Mostly met. Weak points: off-site recovery (11) and awareness (14) |
| IG2 | Strong on identity, logging and configuration. Gaps: container hardening and data protection at rest |
| IG3 | Partial. No formal penetration testing or application security program |
