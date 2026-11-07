# Set up device management

**Goal:** Enroll Apple devices in Fleet to enforce a passcode floor and keep the VPN on, with an inventory of what is enrolled.

**Why:** [ADR-0012](../adr/0012-fleet-for-mobile-device-management.md). **Accept with:** [ATP-010](../atp/ATP-010-endpoint-management.md).

| Piece | Location |
|---|---|
| VM | `mdm01`, VMID 4171 |
| Stack | `roles/fleet`: Fleet, MySQL 8.4, Redis, in `/opt/fleet`; nightly dump 01:30 |
| Edge | Caddy site `mdm`: device paths public, console internal only |
| Console sign-in | Authentik SAML, group `fleet-admins` |
| Configuration | `fleet/default.yml`, `fleet/profiles/apple/`, applied by `bin/fleet-gitops` |
| Secrets | OpenBao `kv/services/prod/fleet` |

## What the free tier does

| Capability | Fleet Free |
|---|---|
| Personal-device enrollment, profiles | Yes |
| Custom MDM commands | Yes, except lock and wipe |
| Console SSO, GitOps, API, inventory | Yes |
| Remote lock and wipe | **No**; use Find My |
| App deployment (VPP) | **No**; Tailscale is managed with a custom command |
| OS update enforcement, teams | **No** |

Whoever holds a phone can remove the profile, which also removes what it installed. This is a floor, not a lock.

**Privacy.** Fleet sees model, serial, OS version, managed items, storage and battery. It does not see photos, messages, browsing or personal apps. Enroll someone else's device only with their knowledge and agreement.

## Roll out

1. **Secrets.**
   ```bash
   bin/gen-service-secrets prod
   ```
2. **Identity.** Expect 1 group, 1 SAML provider, 1 application, 1 binding. Add yourself to `fleet-admins`.
   ```bash
   bin/tf-ak prod plan && bin/tf-ak prod apply
   ```
3. **VM and firewalls.** Check the node has about 3 GB free first.
   ```bash
   bin/tf prod plan && bin/tf prod apply
   ```
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml
   ```
   ```bash
   bin/ap prod playbooks/platform.yml --limit step_ca
   ```
4. **Configure, then the edge and DNS.** Add a public `mdm` CNAME.
   ```bash
   bin/ap prod playbooks/services.yml --limit mdm01
   ```
   ```bash
   bin/ap prod playbooks/services.yml --limit caddy
   ```
   ```bash
   bin/ap prod playbooks/unifi_dns.yml
   ```
5. **Admins,** from inside the network. Create a break-glass admin (keep its password in the password manager), your SSO user with your Authentik e-mail, since Free has no JIT provisioning, and an API user. The token goes directly into OpenBao, never to the screen.
   ```bash
   fleetctl config set --address https://mdm.example.com
   ```
   ```bash
   fleetctl setup --email breakglass@example.com --name "Break glass" --org-name labstack
   ```
   ```bash
   fleetctl user create --name Alice --email alice@example.com --sso --global-role admin
   ```
   ```bash
   fleetctl user create --api-only --name gitops --global-role admin | awk '/API token/ {print $NF}' | bin/bao-secret prod set fleet_gitops_token
   ```
6. **Apple push certificate.** In the console: Settings, Integrations, MDM, Apple, Turn on, Download CSR. Upload it at the [Apple Push Certificates Portal](https://identity.apple.com/pushcert) and upload the resulting `.pem`. Record the Apple Account in the recovery kit, because every renewal must use the same one. Set a reminder for 11 months.
7. **Configuration.** Profiles are refused until step 6 is done.
   ```bash
   bin/fleet-gitops prod --dry-run
   ```
   ```bash
   bin/fleet-gitops prod
   ```
8. **Check.** From cellular, the console returns 403, and `/enroll` loads and reports an invalid secret. That is correct: the path is public, the secret is not.

## Enroll a device

1. Open the enrollment link in Safari (console: Hosts, Add hosts, iOS & iPadOS, Personal).
2. Download the profile, then Settings, Profile Downloaded, Install, Trust.
3. The device shows "On (manual - personal)" within a minute. VPN settings show Connect On Demand on and greyed out. Delete any unmanaged Tailscale entry.
4. Take Tailscale under management. The phone asks once. The app then uses the server without typing and cannot be switched off.
   ```bash
   bin/mdm-tailscale <serial> alice-phone
   ```
5. [Trust it on the VPN](vpn.md#trust-a-device).

## Verify

```bash
fleetctl get hosts
```
```bash
curl -s -o /dev/null -w '%{http_code}\n' https://mdm.example.com/login
```

From outside, expect 403. In the console, the host's OS settings show both profiles as Verified.

## Maintain

| Task | Action |
|---|---|
| Change a profile | Edit in `fleet/profiles/apple/`; run `bin/fleet-gitops prod` |
| Device sold | Remove the profile or delete the host, then the Headscale steps |
| Device lost | Find My; expire it in Headscale at once |
| Push certificate (yearly) | Console Renew, then the portal's **Renew** (not Create) with the same account |
| Upgrade | Bump `fleet_version` and `npm:fleetctl` together. MySQL stays on 8.4 |

## Recover

- **`mdm01` lost:** restore from PBS. Do **not** rebuild it empty: the push certificate, SCEP CA and device records are in its database, and a fresh Fleet means re-enrolling everything.
- **`fleet_server_private_key` lost:** what it encrypted is unreadable. Set MDM up again and re-enroll.
- **Authentik down:** sign in as break-glass. Phones are unaffected.

## Next step

step-ca supports Apple's Managed Device Attestation, so a phone can prove through Apple that a Secure Enclave key belongs to that device. A trusted device then becomes proven instead of listed.
