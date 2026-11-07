# ATP-006: Edge and identity

**Objective:** Prove internet-facing access control. Run from outside: a phone on cellular with Wi-Fi and VPN off.

| ID | Test | Steps | Expected |
|---|---|---|---|
| T1 | Site exposure matrix | Script in [Control public exposure](../howto/public-exposure.md) | Matches the table; `sync` and admin paths 403 |
| T2 | MFA required | Sign in to `auth` with only a correct password | Second factor demanded |
| T3 | Reputation lockout | Repeated failed logins from one source | Refused; rules 100203, then 100204 |
| T4 | Per-application authorization | A user outside an application's group opens it | Authentik denies access |
| T5 | Password login bypass | [Jellyfin script](../howto/jellyfin-sso.md#verify-from-outside) with case, encoding and prefix variants | All password, Startup and SAML paths 403 |
| T6 | Header spoofing | From outside, send `Remote-User: admin` and `X-Labstack-Device-Key: x` to a forward-auth site | Ignored; login required. Caddy strips and sets these itself |
| T7 | Sensitive data out of logs | Complete an OIDC login, then read Caddy's log | Codes and tokens are absent from logged query strings |
| T8 | TLS configuration | `testssl.sh https://auth.example.com` | Valid chain; TLS 1.2+ only; no critical findings. Record header results for the [open gap](../compliance/top-10-lists.md) |

**Evidence:** Saved output from the outside network.
