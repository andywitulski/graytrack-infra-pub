# NIST CSF 2.0 mapping

Coverage by category. LC references are in the [control catalog](control-catalog.md), and G references in the [gap register](gap-register.md).

## GOVERN (GV)

| Category | How it is met | Controls | Status |
|---|---|---|---|
| GV.OC Organizational Context | Purpose and scope in [architecture](../architecture/overview.md) | | Partial |
| GV.RM Risk Management Strategy | Residual risks recorded in ADRs; gap register | | Partial |
| GV.RR Roles, Responsibilities | Small team; [access lifecycle](../admin/access-lifecycle.md) | LC-16 | Partial |
| GV.PO Policy | Enforced as code, with no separate policy documents | LC-27, LC-28 | Partial |
| GV.OV Oversight | Quarterly ATPs, ADR risk review | | Partial |
| GV.SC Supply Chain Risk | Pins, checksums, Renovate | LC-31 | Partial; G-19 |

## IDENTIFY (ID)

| Category | How it is met | Controls | Status |
|---|---|---|---|
| ID.AM Asset Management | Inventories and OpenTofu are the record; Fleet for mobile; Wazuh for software | LC-27, LC-33, LC-25 | Implemented |
| ID.RA Risk Assessment | Vulnerability detection; ADR risk sections; this assessment | LC-25 | Partial; G-15 |
| ID.IM Improvement | Lessons in guides; ADR updates; [IR step 5](../runbooks/incident-response.md#5-learn) | LC-36 | Partial |

## PROTECT (PR)

| Category | How it is met | Controls | Status |
|---|---|---|---|
| PR.AA Identity, Authentication, Access Control | SSO, MFA, short-lived certificates, per-application groups, machine policies | LC-07-LC-17 | Partial; G-07, G-08, G-10 |
| PR.AT Awareness and Training | Walk-throughs and guides | | N/A at this scale |
| PR.DS Data Security | Encrypted state, secrets, backups; TLS | LC-17, LC-19, LC-21, LC-34 | Partial; G-04, G-09 |
| PR.PS Platform Security | Baseline, patching, IaC, logging, pinned software | LC-24, LC-27, LC-28, LC-30, LC-31 | Implemented; G-05 |
| PR.IR Infrastructure Resilience | Segmentation, backup, node quorum | LC-01-LC-03, LC-34 | Partial; G-01, G-02, G-18 |

## DETECT (DE)

| Category | How it is met | Controls | Status |
|---|---|---|---|
| DE.CM Continuous Monitoring | Agents, gateway, edge, identity, firewall, ZFS and backup events | LC-22, LC-24, LC-25 | Implemented |
| DE.AE Adverse Event Analysis | Custom rules with levels, frequency correlation, framework tags | LC-23 | Partial; G-03 |

## RESPOND (RS)

| Category | How it is met | Controls | Status |
|---|---|---|---|
| RS.MA Incident Management | [IR runbook](../runbooks/incident-response.md) | LC-36 | Partial; G-20 |
| RS.AN Incident Analysis | Attributable logins, CA issuance logs, audit logs | LC-07, LC-18, LC-22 | Implemented |
| RS.CO Reporting and Communication | Record template and notification note | LC-36 | Partial; G-03 |
| RS.MI Incident Mitigation | Revocation, exposure switch, device removal, firewall isolation | LC-03, LC-09, LC-06 | Implemented |

## RECOVER (RC)

| Category | How it is met | Controls | Status |
|---|---|---|---|
| RC.RP Recovery Plan Execution | [DR scenarios](../runbooks/disaster-recovery.md), rebuild order, verify step | LC-34, LC-35 | Partial; G-01, G-20 |
| RC.CO Recovery Communication | Small user group, direct contact | | N/A at this scale |
