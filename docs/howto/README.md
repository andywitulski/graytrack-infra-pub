# How-to guides

Task guides for building and changing components. Each states its goal, prerequisites, steps, how to verify, and
how to back out. For failures use the [runbooks](../runbooks/README.md); for routine work use the
[admin walk-throughs](../admin/README.md).

| Area | Guide | Goal |
|---|---|---|
| Platform | [Build the platform tier](platform-tier.md) | State backend, secrets manager, migrating roots |
| | [Manage secrets in OpenBao](secrets-openbao.md) | Add, rotate and cut over service secrets |
| | [Build the certificate authority](certificate-authority.md) | step-ca and SSH certificates, phases 1 and 2 |
| | [Use certificates](using-certificates.md) | Log in, git over SSH, issue and revoke |
| | [Serve admin UIs with internal TLS](admin-ui-tls.md) | Replace self-signed certificates |
| Access | [Roll out device trust](device-trust.md) | vTPMs, sealed credentials, device as a factor |
| | [Set up remote access](vpn.md) | Headscale, clients, device trust, exit node |
| | [Set up device management](mdm.md) | Fleet and enrollment |
| | [Deploy the password manager](password-manager.md) | Vaultwarden with SSO |
| Network | [Roll out host firewalls](host-firewall.md) | Audit, then enforce |
| | [Control public exposure](public-exposure.md) | Publish sites safely, close them again |
| Monitoring | [Connect SIEM log sources](siem-sources.md) | Caddy, Authentik, gateway |
| | [Add SSO to the SIEM dashboard](siem-sso.md) | SAML through Authentik |
| Resilience | [Configure backups](backups-pbs.md) | PBS, encryption key |
| | [Mirror git offsite](git-mirrors.md) | Forgejo push mirrors |
| Environments | [Build the lab node](lab-node.md) | Node, PAW, GPU guest, Kali, dev |
| | [Build the dev environment](dev-environment.md) | Nested pre-production cluster |
| Applications | [Run the mail hub](mail.md) | Stalwart with synced accounts |
| | [Plan the public mail edge](mail-public-edge.md) | Stage 2: VPS relay |
| | [Add Jellyfin SSO](jellyfin-sso.md) | No password prompt on the internet |
| | [Deploy Audiobookshelf](audiobookshelf.md) | OIDC, safe first-run claim |
| | [Add files to media libraries](media-drop.md) | SMB drop shares |
| | [Enable Nextcloud Office](nextcloud-office.md) | Apps and Collabora |
| | [Set up file shares and migrate repositories](file-shares-and-repo-migration.md) | Samba, Forgejo imports |
