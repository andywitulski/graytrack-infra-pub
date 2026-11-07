# Access lifecycle

Joiner, mover and leaver procedures. Access always needs two gates: Authentik decides who gets a credential, and the code decides where it works.

## Joiner

1. **Create the account in Authentik.** They enroll MFA at first sign-in, ideally two factors.
2. **Grant least privilege.** Add only the groups they need.

   | Group | Grants |
   |---|---|
   | `ssh-admins` | SSH certificates for hosts and Forgejo |
   | `forgejo-users` | Forgejo only |
   | `headscale-users` | VPN sign-in |
   | `vaultwarden-users` | Password manager |
   | `jellyfin_users`, `audiobookshelf-users` | Media |
   | `wazuh-readonly-users`, `wazuh-administrators` | SIEM |
   | `fleet-admins` | MDM console |

3. **Host access, if needed.** Add to `ssh_ca_people` and run the play. Set `sudo: false` unless admin rights are required.
   ```yaml
   - { name: bob, comment: "Bob User", sudo: false }
   ```
   ```bash
   bin/ap prod playbooks/ssh-ca.yml
   ```
4. **VPN.** Add to `headscale_users`, run the `hs01` play, enroll, then [trust each device](../howto/vpn.md#trust-a-device).
5. **Mail, shares:** add to `mail_users` and `samba_users` as needed.
6. **Forgejo:** they add their certificate principal in settings.

**Verify:** they can do what they need, and an admin-only surface refuses them.

## Mover

Change groups in Authentik and the matching lists in code in one change. **Remove what the new role does not need, as well as adding what it does.**

## Leaver

Do this promptly, in this order. Certificates can last up to 24 h, so step 3 matters.

1. **Authentik:** remove from groups, deactivate, end all sessions. No new certificates from here on.
2. **Hosts:** remove from `ssh_ca_people`, add to `ssh_ca_people_absent`.
3. **Revoke certificates already held:** add `ssh_ca_revoked: ["id: their@email"]`.
4. Apply. The principal file and account go, and the KRL takes effect.
   ```bash
   bin/ap prod playbooks/ssh-ca.yml
   ```
5. **VPN:** for each of their devices, expire it, remove its `headscale_trusted_devices` line, and delete it. Removing the group does not cut off joined devices.
   ```bash
   ssh ansible@hs01 'sudo headscale nodes expire --identifier <ID>'
   ```
6. **Device trust:** delete their `trusted_devices` lines and apply `bin/tf-ak prod apply`.
7. **Applications:** block in Forgejo. Remove from `mail_users`, then delete the mailbox in the portal. Revoke Nextcloud and Authentik app passwords. In Vaultwarden, remove from any organization.
8. **Shared secrets they knew:** rotate them.
9. **MDM:** remove their device's profile or delete the host.
10. Remove the `id:` revocation after a day, when every certificate has expired.

**Verify:** a login with their last certificate is refused, and the leaver is absent from `sudo headscale nodes list`.

## Review access

Monthly. For each, confirm that every entry is still needed:

| Check | Where |
|---|---|
| Group membership | Authentik, Directory, Groups |
| Host accounts | `ssh_ca_people` |
| Trusted devices | `headscale_trusted_devices`, `trusted_devices` |
| Exit node grants | `headscale_exits` |
| API tokens, app passwords | Authentik; Forgejo; Fleet |
| Provisioners, OpenBao identities | `tofu/openbao/<env>` |

Record the date and result in a commit or review note.
