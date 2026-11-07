# Incident response

A short procedure for a small team, following the NIST SP 800-61 lifecycle. Start here when an alert or
observation suggests compromise.

## Severity

| Severity | Examples | Respond |
|---|---|---|
| Critical | Rule 100451 unplanned (break-glass), CA or age key exposure, active attacker | Now |
| High | Rule 100402 (automation account from elsewhere), 100208 (impersonation), 100207 (secret viewed unexpectedly), 100434 (audit tampering) | Within hours |
| Medium | 100204 or 100103 (password guessing), 100309 (threat), 100423 (lateral movement or scan) | Same day |
| Low | Scanner noise, 100105 (path probing) | Review daily |

## 1. Detect and triage

1. Open the alert in the Wazuh dashboard. If you do not trust `siem01`, read the logs on the source host too.
2. Ask: was this planned? Check recent commits and any maintenance in progress.
3. Decide severity and start a [record](#record) with a timestamp.

## 2. Contain

Prefer actions that preserve evidence: **isolate, do not delete.**

| Situation | Action |
|---|---|
| Compromised account | Disable it in Authentik; end its sessions; revoke its certificates by key ID |
| Compromised guest | Snapshot it, then cut it off: set a blocking guest firewall, or disconnect the NIC in Proxmox |
| Internet-facing abuse | Set `unifi_public_exposure: false` and run `unifi_firewall.yml` |
| Stolen or lost device | Expire it in Headscale, remove its trust line, delete its `trusted_devices` entry, sign it out everywhere |
| Leaked key or secret | [Rotate](certificate-rotation-and-compromise.md) |
| A secret committed to a public repository | Treat it as compromised. Rotate first; rewriting history does not undo the exposure |

## 3. Investigate

| Question | Where to look |
|---|---|
| Who logged in, with what? | sshd logs carry the certificate key ID and serial; rules 100450-100452 |
| What certificates were issued? | `journalctl -u step-ca -u step-ca-login` on `ca01`; database `stepca` |
| Which secrets were read? | `/var/log/openbao/audit.log` on `bao01` |
| What changed on the host? | Wazuh syscheck; `auditd` rules; commit history |
| Which connections were made? | Gateway rules 100306-100308; firewall rules 100421-100423 |
| Identity activity | Authentik events, rules 100200-100212 |

Copy evidence off the host before rebuilding.

## 4. Eradicate and recover

Rebuild rather than clean: code and state make this cheap.

1. Restore from a backup taken before the first sign of compromise, or rebuild ([DR scenario A](disaster-recovery.md#a-one-guest-broken)).
2. A rebuilt or restored VM trips its TPM pin. Investigate, then accept deliberately ([guide](../howto/device-trust.md#1-add-vtpms)).
3. Rotate every credential the host could read.
4. Patch the entry point.
5. [Verify](disaster-recovery.md#verify-after-any-recovery).

## 5. Learn

Within a week, write a blameless review: timeline, what worked, what did not, and action items. Add a detection and a sample to `wazuh_manager_logtest_samples` if the event was missed. Update the affected ADR, control status or ATP.

## Record

```text
ID / severity / status:
Detected at, by (rule or person):
Summary:
Timeline (UTC):
Scope: hosts, accounts, data
Actions taken:
Root cause:
Follow-ups (owner, date):
```

Keep records in a private repository. They are not published here.

## Notification

If personal data of others may be affected, tell those people and consider any legal obligations. Get appropriate advice for your jurisdiction.
