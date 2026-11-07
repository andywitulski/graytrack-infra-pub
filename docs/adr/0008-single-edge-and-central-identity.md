# ADR-0008: One inbound path and central identity

| | |
|---|---|
| **Status** | Accepted |
| **Date** | Recorded retroactively 2026-11-05 |
| **Controls** | NIST AC-3, AC-17, IA-2(1), IA-8, SC-7, AC-7; OWASP A01, A07 |

## Context

Many applications need to be reachable from outside, each with its own login, admin surface and CVEs. Exposing
each one directly multiplies attack surface and leaves MFA to each application.

## Decision drivers

- Reduce the number of internet-facing services to audit.
- MFA in one place, enforced before applications where possible.
- Admin paths must not be reachable from the internet even on public sites.
- Exposure must be easy to reverse.

## Options considered

| Option | Assessment |
|---|---|
| Port-forward each application | Most surface; inconsistent authentication |
| VPN only | Excludes devices that cannot run a client and external sharing |
| Reverse proxy in a DMZ plus an IdP | One audited path; per-site policy; central MFA |

## Decision

- **`edge01`** in a DMZ, running **Caddy**, is the only WAN target for web traffic. Each site declares `public`, `lan_paths` or `public_path_regexp`. Sites default to internal only.
- **Authentik** provides OIDC, SAML, LDAP outposts, forward auth, MFA enrollment at first sign-in and reputation lockout, all as code in `tofu/modules/authentik_config`.
- Access is per application, through group bindings.
- Where a protocol cannot do MFA, its path is closed to the internet. Jellyfin password login, which binds LDAP and would allow password guessing without MFA, is blocked with a case-insensitive regexp tested against encoding and path bypasses.
- The port forward is controlled by one switch, `unifi_public_exposure`.

## Consequences

- **Positive:** One place to log, rate-limit and block. Removing a person from a group removes access.
- **Negative:** `edge01` and `idp01` are single points of failure for web access.
- **Residual risks:** Trust-based `lan_paths` rely on the source address, so a compromised internal host passes them. Internal hops behind Caddy are HTTP. Caddy sets no global security headers, so applications rely on their own (tracked in the [OWASP mapping](../compliance/top-10-lists.md)).

## Validation

[ATP-006](../atp/ATP-006-edge-and-identity.md).

## Related

[Control public exposure](../howto/public-exposure.md), [Jellyfin SSO](../howto/jellyfin-sso.md)
