# Certificate rotation and compromise

## Decide what leaked

| What leaked | Exposure | Response |
|---|---|---|
| One short-lived certificate and key | Until it expires (8 or 16 h) | [Revoke now](../howto/using-certificates.md#admin-tasks) |
| A provisioner password | Can mint that identity's certificates | Rotate it; revoke what was issued since |
| `ca01` keys on disk | Intermediate and both SSH CAs | Rotate all three; rebuild `ca01` |
| `secrets/ca-<env>.enc.yaml` or the age key | Everything online | As above, plus rotate the age key and re-encrypt sops |
| `secrets/ca-<env>-root.enc.yaml` | The root | New CA from scratch: `bin/ca-init` and redeploy trust everywhere |

Open an [incident record](incident-response.md) for anything beyond a single short-lived certificate.

## Rotate the intermediate CA

Needs the root, on a controller only. The root does not change, so clients are unaffected. Old certificates stay valid until they expire, within 8 to 24 h.

```bash
work=$(mktemp -d -p "${XDG_RUNTIME_DIR:-/tmp}"); umask 077
for k in root_ca_crt root_ca_key root_ca_password; do sops decrypt --extract "[\"$k\"]" secrets/ca-prod-root.enc.yaml > "$work/$k"; done
sops decrypt --extract '["ca_password"]' secrets/ca-prod.enc.yaml > "$work/ca.pw"
step certificate create "labstack prod Intermediate CA" "$work/int.crt" "$work/int.key" --profile intermediate-ca --ca "$work/root_ca_crt" --ca-key "$work/root_ca_key" --ca-password-file "$work/root_ca_password" --password-file "$work/ca.pw" --not-after 43800h
step certificate verify "$work/int.crt" --roots "$work/root_ca_crt"
jq -Rs . < "$work/int.crt" | sops set --value-stdin secrets/ca-prod.enc.yaml '["intermediate_ca_crt"]'
jq -Rs . < "$work/int.key" | sops set --value-stdin secrets/ca-prod.enc.yaml '["intermediate_ca_key"]'
cp "$work/int.crt" ansible/files/prod/ca01-intermediate.pem
find "$work" -type f -exec shred -u {} +; rmdir "$work"
```
```bash
bin/ap prod playbooks/platform.yml --limit step_ca
```

## Rotate the SSH user CA (overlap, no downtime)

The new key goes first, since it signs and the KRL is scoped to it. The old key goes second, still trusted.

```bash
work=$(mktemp -d -p "${XDG_RUNTIME_DIR:-/tmp}"); umask 077
sops decrypt --extract '["ca_password"]' secrets/ca-prod.enc.yaml > "$work/ca.pw"
step crypto keypair "$work/new.pub" "$work/new.key" --kty EC --crv P-256 --password-file "$work/ca.pw"
jq -Rs . < "$work/new.key" | sops set --value-stdin secrets/ca-prod.enc.yaml '["ssh_user_ca_key"]'
{ step crypto key format "$work/new.pub" --ssh; echo; cat ansible/files/prod/ca01-ssh-user-ca.pub; } | grep . > "$work/both"
cp "$work/both" ansible/files/prod/ca01-ssh-user-ca.pub
find "$work" -type f -exec shred -u {} +; rmdir "$work"
```
```bash
bin/ap prod playbooks/platform.yml --limit step_ca
```
```bash
bin/ap prod playbooks/ssh-ca.yml
```
```bash
bin/ap prod playbooks/services.yml --limit git01
```

After 24 h, the longest user certificate, delete the second line of the `.pub` file and run the last two plays again. **If the old key was compromised, skip the overlap:** remove it immediately and accept the disruption.

## Rotate the SSH host CA

Same steps with `ssh_host_ca_key` and `ca01-ssh-host-ca.pub`. Every host is re-signed on the next `ssh-ca.yml` run. Give everyone else's `known_hosts` the new line before dropping the old key.

## Rotate other credentials

| Credential | Action |
|---|---|
| Provisioner password | `bin/ca-rotate-provisioner prod <name>`, then the `step_ca` play |
| Database password | Change `stepca_pg_password` in sops, then `platform.yml` |
| Age key | Generate new, add to `.sops.yaml`, `sops updatekeys` on every file, remove the old one, replace offline copies. Git history still holds old ciphertext, so rotate what the old key protected |

## Use break-glass

When `ca01` or Authentik cannot issue. Each login raises **rule 100451, level 12**, and the issue is logged in `~/.local/state/labstack/breakglass.log`.

```bash
bin/ssh-cert prod breakglass ansible 1
```
```bash
LABSTACK_SSH=breakglass bin/ap prod playbooks/<the-fix>.yml
```
```bash
bin/ssh-cert prod breakglass alice 2
```
```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/labstack/prod/breakglass-alice alice@<host>
```

Practice this quarterly ([ATP-003](../atp/ATP-003-certificates-and-ssh.md)).

## Locked out completely

When `ca01` is down and sops is unavailable:

| Target | Action |
|---|---|
| LXC | On the node: `pct enter <vmid>`, then put a key back or fix sshd |
| VM | `qm guest exec <vmid> -- bash -c 'mkdir -p ~ansible/.ssh; echo "<pubkey>" >> ~ansible/.ssh/authorized_keys'`, or the console |
| Node | Physical console, or root SSH from another node |

Re-run `ssh-ca.yml` once `ca01` is back: it removes the emergency key.

## Other failure states

| Situation | Effect | Fix |
|---|---|---|
| `ca01` down, nothing lost | Automation falls back; issued certificates work until expiry | `pct status 4321`, `journalctl -u step-ca`, `platform.yml --limit step_ca` |
| `pg01` lost | step-ca cannot start | Restore `pg01`, restart both units. An older `used_ott` table is harmless: tokens are single-use and short-lived |
| Authentik down | `step-ca-login` retries every 15 s; automation is unaffected | Break-glass for your own account |
| Host certificates expired (no play for 90 days) | Clients fall back to the plain host key | `LABSTACK_SSH=cert bin/ap prod playbooks/ssh-ca.yml` |
