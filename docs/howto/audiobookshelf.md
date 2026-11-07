# Deploy Audiobookshelf

**Goal:** Run Audiobookshelf on `media01` with OIDC, without ever exposing the unclaimed first-run page.

**Why the order matters:** until a root user exists, anyone who reaches `/init` owns the server. The role claims it on loopback in the same run that installs the package. Public DNS is created last, so the unclaimed window is never reachable from outside.

| Piece | Location |
|---|---|
| Install, hardening, claim, libraries, OIDC | `ansible/roles/media/tasks/audiobookshelf.yml` |
| Libraries | `/srv/audiobooks`, `/srv/podcasts`, `/srv/ebooks` on ZFS `tank/*` |
| Sign-in | Authentik OIDC; groups `audiobookshelf-users`, `audiobookshelf-admins` |
| Account type | Claim `abs_roles`; no group, no login |
| Break-glass | Local `abs-root`, password in OpenBao |

**Why no forward auth:** the mobile apps use OIDC through the application's own redirect and cannot follow a proxy login page.

## Steps

1. **Secrets.**
   ```bash
   bin/gen-service-secrets prod
   ```
2. **Identity.** Expect 2 groups, a mapping, a provider, an application and 2 bindings.
   ```bash
   bin/tf-ak prod plan && bin/tf-ak prod apply
   ```
3. **Storage and mounts.** `media01` restarts.
   ```bash
   bin/ap prod playbooks/storage.yml
   ```
   ```bash
   bin/ap prod playbooks/lxc_host.yml --limit pve03
   ```
4. **Firewalls.** `media01` gains port 13378, from `edge01` only. It also needs a path to `edge01:443`, because the application fetches the IdP's discovery document through the edge.
   ```bash
   bin/tf prod plan && bin/tf prod apply
   ```
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml
   ```
5. **Edge, then application.** The run installs, claims, creates libraries and configures OIDC. It skips OIDC while the secret is PENDING.
   ```bash
   bin/ap prod playbooks/services.yml --limit caddy
   ```
   ```bash
   bin/ap prod playbooks/services.yml --limit media
   ```
   ```bash
   bin/ap prod playbooks/unifi_dns.yml
   ```
6. **Verify inside.** A private window goes straight to Authentik. `/login/?autoLaunch=0` shows the local form.
7. **Public DNS last.**

## Verify from outside

```bash
curl -s https://books.example.com/status | jq '{isInit, authMethods}'
```
```bash
curl -s -X POST -o /dev/null -w '%{http_code}\n' https://books.example.com/init
```

Expect `isInit: true`, and `/init` returning 500 because it is already claimed.

## Notes

- Caddy removes `setToken`, `accessToken` and `token` from logged query strings, because session tokens travel there.
- UI library edits are kept. The role only creates libraries missing by name.
- The package comes from the vendor's apt repository, so `patch.yml` upgrades it, while unattended security updates do not. Pin with `media_abs_version`.
