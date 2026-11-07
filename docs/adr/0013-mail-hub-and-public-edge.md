# ADR-0013: Internal mail hub now, public mail edge deferred

| | |
|---|---|
| **Status** | Stage 1 accepted and running; stage 2 proposed |
| **Date** | Recorded retroactively 2026-11-05 |
| **Controls** | NIST SC-8, SC-28, SC-23, AC-3, CP-9 |

## Context

Users hold several external mail accounts and want one mailbox. Self-hosting public mail has specific problems:
residential ISPs block outbound port 25, and a new IP has no reputation.

## Decision drivers

- One place to read and answer all accounts.
- No new public attack surface.
- Sending must keep the provider's SPF and DKIM.
- Migration must be reversible.

## Options considered

| Option | Assessment |
|---|---|
| Keep separate accounts | No consolidation |
| Public MX at the site | Blocked by the ISP; poor reputation |
| Internal Stalwart hub with two-way sync | No public surface; providers remain source of truth |
| VPS as public MX and relay in front of the hub | Own the domain's mail, with mailboxes at the site |

## Decision

**Stage 1:** Stalwart on `mail01`, reachable from LAN and VPN only, on an internal domain never in public DNS.
`mbsync` syncs both ways, and each message is sent through the account it is from. Each person may send only as
their own addresses.

**Stage 2 (proposed, not built):** A small VPS is the public MX and outbound relay in front of the hub over the
tailnet. A smarthost is recommended at first, because new IPs commonly land in spam.

## Consequences

- **Positive:** No inbound mail ports. If the hub is lost, resyncing restores everything.
- **Negative:** Sync credentials are app passwords in OpenBao. Two-factor sign-in cannot be used on the mailbox account, because the sync logs in with its password.
- **Residual risks:** Emptying Deleted Items deletes messages at the provider. Starting over without clearing sync state would read an empty store as a mass delete; the [procedure](../howto/mail.md) stops sync first.

## Validation

[ATP-011](../atp/ATP-011-applications.md).

## Related

[Run the mail hub](../howto/mail.md), [Plan the public edge](../howto/mail-public-edge.md)
