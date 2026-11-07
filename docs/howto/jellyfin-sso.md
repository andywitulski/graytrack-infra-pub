# Add Jellyfin SSO

**Goal:** Make Jellyfin reachable from the internet with no password prompt: Authentik with MFA for browsers, Quick Connect for apps and TVs.

**Why this matters:** Jellyfin apps cannot do OIDC, and LDAP binds skip MFA. Exposing the password form would let the internet test real directory passwords. Quick Connect delegates a signed-in session to a device, the same idea as the OAuth device flow (RFC 8628).

**Accept with:** [ATP-006](../atp/ATP-006-edge-and-identity.md).

## What is blocked from outside

| Path | Why |
|---|---|
| `/Users/AuthenticateByName`, `/Users/{id}/Authenticate` | Password login, both API forms |
| `/Users/ForgotPassword`, `/Users/ForgotPassword/Pin` | Password reset |
| `/Startup/*` | First-run wizard |
| `/sso/SAML/*` | Unused plugin endpoints |

Jellyfin routes are case-insensitive and also answer under `/emby`, so a plain path match can be bypassed. The regexp was tested against mixed case, `/emby` prefixes, doubled slashes, `/./` and `/../`, `%42` and `%2F` encoding, trailing slashes and query strings. All return 403.

## Steps

1. **Identity.** Expect a provider, an application and 2 bindings. Use groups `jellyfin_admins` and `jellyfin_users`.
   ```bash
   bin/tf-ak prod plan && bin/tf-ak prod apply
   ```
2. **Plugin,** from inside. Add the SSO plugin repository and install "SSO Authentication". The original plugin was archived in 2026 and the fork is community-maintained, so upgrade on purpose and note the version.
   ```text
   https://raw.githubusercontent.com/k0lin/jellyfin-plugin-sso/manifest-release/manifest.json
   ```
3. **Provider** (Plugins, SSO-Auth):

   | Field | Value |
   |---|---|
   | Name | `authentik` (it is in the redirect URI) |
   | OpenID endpoint | `https://auth.example.com/application/o/jellyfin/` |
   | Client ID | `jellyfin` |
   | Client secret | `bin/tf-ak prod output -raw jellyfin_client_secret` |
   | Enabled, Enable authorization | On |
   | Roles | `jellyfin_users`, `jellyfin_admins` |
   | Admin roles | `jellyfin_admins` |
   | Role claim | `groups` |
   | Scheme override | `https`, or the redirect URI will be `http://` |

   Role matching is exact and case-sensitive. A user in neither group is refused.
4. **Login button** (General, Branding, login disclaimer):
   ```html
   <a href="/sso/OID/start/authentik" class="raised block emby-button">Sign in with Authentik</a>
   ```
5. **Settings.** Quick Connect on. Known proxies `__DMZ_NET__.10`, so logs and lockout see the client's address. Login attempts before lockout: 5.
6. **Edge.** Internal clients notice nothing.
   ```bash
   bin/ap prod playbooks/services.yml --limit caddy
   ```

## Sign in a device

1. In the app, enter the server and choose Quick Connect. It shows a code.
2. On a phone, open `https://media.example.com/sso/OID/start/authentik` and sign in.
3. In that session: user menu, Quick Connect, enter the code.

Typing a password into the app from outside gets a 403. That is the design.

## Verify from outside

```bash
for p in /System/Info/Public /Users/AuthenticateByName /users/authenticatebyname /emby/Users/AuthenticateByName //Users/AuthenticateByName /Startup/Configuration /sso/SAML/start/x /sso/OID/start/authentik; do printf '%-36s ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' -X POST "https://media.example.com$p"; done
```

Expect 200 or 405 for `System/Info/Public`, 403 for every password, Startup and SAML path, and 302 or 405 for `sso/OID/start`. Afterward, confirm LDAP password login still works from inside for the same account.

## Close it

Remove `public: true` from the `media` site and rerun Caddy.
