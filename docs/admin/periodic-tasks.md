# Periodic tasks

## Monthly

| Task | How | Pass |
|---|---|---|
| Run the certificate play by hand if the timer has any doubt | `bin/ap prod playbooks/ssh-ca.yml` | No host under 30 days ([one-liner](../howto/using-certificates.md#admin-tasks)) |
| Review access | [Access review](access-lifecycle.md#review-access) | Every grant still justified |
| Rerun the CIS scan | Wazuh SCA; compare with the [exceptions](../compliance/cis-debian13-exceptions.md) | Only recorded exceptions fail |
| Review public exposure | Run the [outside check](../howto/public-exposure.md) | Matches the expected table |
| Download a gateway backup | Console, after any big change | `.unf` stored safely |

## Quarterly

| Task | How | Evidence |
|---|---|---|
| Restore `pg01` to a spare VMID | [ATP-009](../atp/ATP-009-backup-restore.md) | Output |
| Restore one service VM | [ATP-009](../atp/ATP-009-backup-restore.md) | Screenshot or output |
| Practice break-glass | [Procedure](../runbooks/certificate-rotation-and-compromise.md#use-break-glass); rule 100451 fires | Alert excerpt |
| Rotate AppRole secret IDs if used (90-day expiry) | `bin/bao-approle prod ansible`, and `tofu`, `tf-authentik` | Commit |
| Run the full [ATP suite](../atp/README.md) | Each ATP | `docs/evidence/` in your private fork |
| Update the [control status](../compliance/README.md) | Against ATP results | Commit |

## Twice a year

| Task | How |
|---|---|
| Check the [recovery kit](../runbooks/disaster-recovery.md#recovery-kit) | Decrypt a sops file with the offline age key copy; check GitHub recovery codes |
| Review ADR residual risks | Is each accepted risk still acceptable? |
| Review Authentik groups, app passwords and API tokens | Remove what is unused |

## Yearly

| Task | When | Notes |
|---|---|---|
| Rebuild a controller from scratch | Any | [DR scenario D](../runbooks/disaster-recovery.md#d-controller-lost) on a spare machine |
| Renew Apple push certificate | 11 months after creation | [Same Apple Account](../howto/mdm.md#maintain) |
| Renew GitHub mirror token | Before expiry | [Procedure](../howto/git-mirrors.md#replace-the-token) |
| Rotate provisioner passwords | Any | `bin/ca-rotate-provisioner` |
| Consider a seal key rotation | Any | [Procedure](../howto/platform-tier.md#rotate) |
| Check CA expiry | Internal per-host CAs last 10 years; check the intermediate | `step certificate inspect` |

## Reminder calendar

Put these in a calendar with a person's name on each: push certificate, mirror token, quarterly drills, recovery kit.
