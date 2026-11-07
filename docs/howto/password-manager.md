# Deploy the password manager

**Goal:** Run Vaultwarden on its own VM with SSO, using the official Bitwarden clients.

**Accept with:** [ATP-011](../atp/ATP-011-applications.md).

| Piece | Location |
|---|---|
| VM | `pw01`, VMID 4161 |
| Stack | `roles/vaultwarden`: Vaultwarden and PostgreSQL 16; nightly dump |
| Edge | Caddy site `vault`; `/admin` internal only |
| Sign-in | Authentik OIDC, group `vaultwarden-users`; the master password unlocks the vault |

## How sign-in works

SSO proves who you are to Authentik. Vaultwarden then asks for the **master password**, which decrypts the vault on your device. Neither Authentik nor the server ever sees it. **Lose it and the vault is gone.** Keep it with the [recovery kit](../runbooks/disaster-recovery.md#recovery-kit).

Master password sign-in stays on (`SSO_ONLY=false`), so existing accounts work when Authentik is down. New accounts come only through Authentik (`SIGNUPS_ALLOWED=false`).

**Precondition:** this application uses a mapping that sets `email_verified: true`. That is safe only while people cannot change their own address. In Authentik: System, Settings, *Allow users to change email* **off**.

## Deploy

1. **Secrets.**
   ```bash
   bin/gen-service-secrets prod
   ```
2. **Identity.** Expect 1 group, 1 mapping, 1 provider, 1 application, 1 binding.
   ```bash
   bin/tf-ak prod plan && bin/tf-ak prod apply
   ```
3. **VM and firewalls.** `ca01` signs only names in the inventory as of its last run, so every new host needs its play first.
   ```bash
   bin/tf prod plan && bin/tf prod apply
   ```
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml
   ```
   ```bash
   bin/ap prod playbooks/platform.yml --limit step_ca
   ```
4. **Configure, then the edge and DNS.** The run should end with "Authentik sign-in is on".
   ```bash
   bin/ap prod playbooks/services.yml --limit pw01
   ```
   ```bash
   bin/ap prod playbooks/services.yml --limit caddy
   ```
   ```bash
   bin/ap prod playbooks/unifi_dns.yml
   ```
5. **First account.** In a private window, choose single sign-on and set a long master passphrase. Turn on a second factor for the vault: a hardware key plus TOTP. Print the recovery code.
6. **Clients.** On each one's login screen choose *Self-hosted* with the server URL. Set Bitwarden as the autofill and passkey provider on mobile.
7. **Public.** Add a `vault` CNAME. From cellular, the login page loads and `/admin` returns 403.

## Import passwords

Web vault: Tools, Import data. Delete the export afterward, since it is plain text. Logins from password managers keep their TOTP secrets; authenticator-app entries are added by hand.

## Use the admin page only when needed

It is off unless a token exists. Store an argon2 hash, and unset it when done.

```bash
ssh ansible@pw01 'sudo docker run --rm -it vaultwarden/server:<version> /vaultwarden hash --preset owasp'
```
```bash
bin/bao-secret prod set vaultwarden_admin_token
```
```bash
bin/bao-secret prod unset vaultwarden_admin_token
```

Run the `pw01` play after each change.

## Maintain and recover

| Situation | Action |
|---|---|
| Upgrade | Bump `vaultwarden_version`. Keep it current, especially after security releases |
| `pw01` lost | Restore from PBS. Client offline copies remain readable |
| No backup | Restore the dump and `/opt/vaultwarden/data` (attachments and RSA key) from a file-level restore |
| Authentik down | E-mail and master password |
| Second factor lost | Recovery code |
