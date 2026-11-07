# Identity configuration as code (ADR-0024), shared by every environment: tofu/authentik/<env>
# calls this module with its own domain and addresses, so dev and prod cannot drift apart.

data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_certificate_key_pair" "signing" {
  name = "authentik Self-signed Certificate"
}

data "authentik_flow" "authentication" {
  slug = "default-authentication-flow"
}

data "authentik_property_mapping_provider_scope" "oidc" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-profile",
  ]
}

# For apps that bring their own email mapping (verified_email below): openid and profile only
data "authentik_property_mapping_provider_scope" "oidc_no_email" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
  ]
}

data "authentik_property_mapping_provider_scope" "offline_access" {
  managed_list = ["goauthentik.io/providers/oauth2/scope-offline_access"]
}

# Authentik's own email mapping reports email_verified false (since 2025.10). Vaultwarden refuses an SSO
# signup with an unverified address, and linking accounts by unverified addresses would allow a takeover.
# Here addresses are set by an admin and users cannot change them (default user settings flow: check the
# runbook), so they count as verified. Used in place of the default mapping, never next to it.
resource "authentik_property_mapping_provider_scope" "verified_email" {
  name        = "Verified email (admin-managed addresses)"
  scope_name  = "email"
  description = "email and email_verified true; addresses are set by an admin, not by users"
  expression  = <<-EOT
    return {"email": request.user.email, "email_verified": True}
  EOT
}

# ---------------------------------------------------------------- groups (access is granted by group only)

resource "authentik_group" "lab_admins" {
  name = "lab-admins"
}

resource "authentik_group" "forgejo_users" {
  name = "forgejo-users"
}

resource "authentik_group" "forgejo_admins" {
  name = "forgejo-admins"
}

resource "authentik_group" "nextcloud_users" {
  name = "nextcloud-users"
}

resource "authentik_group" "proxmox_admins" {
  name = "proxmox-admins"
}

resource "authentik_group" "audiobookshelf_users" {
  name = "audiobookshelf-users"
}

resource "authentik_group" "audiobookshelf_admins" {
  name = "audiobookshelf-admins"
}

resource "authentik_group" "vaultwarden_users" {
  name = "vaultwarden-users"
}

resource "authentik_group" "headscale_users" {
  name = "headscale-users"
}

# Audiobookshelf takes its account type from a claim that must list admin, user or guest (it refuses a
# login with none). It requests the claim's name as a scope, so the scope and the claim share a name.
resource "authentik_property_mapping_provider_scope" "abs_roles" {
  name        = "Audiobookshelf roles"
  scope_name  = "abs_roles"
  description = "Audiobookshelf account type from group membership"
  expression  = <<-EOT
    roles = []
    if ak_is_group_member(request.user, name="audiobookshelf-admins"):
        roles.append("admin")
    if ak_is_group_member(request.user, name="audiobookshelf-users"):
        roles.append("user")
    return {"abs_roles": roles}
  EOT
}

# ---------------------------------------------------------------- OIDC applications

locals {
  oidc_apps = {
    forgejo = {
      name      = "Forgejo"
      redirect  = ["https://git.${var.base_domain}/user/oauth2/authentik/callback"]
      groups    = [authentik_group.forgejo_users.id, authentik_group.forgejo_admins.id]
      scopes    = []
      own_email = false
    }
    nextcloud = {
      name      = "Nextcloud"
      redirect  = ["https://cloud.${var.base_domain}/apps/user_oidc/code"]
      groups    = [authentik_group.nextcloud_users.id]
      scopes    = []
      own_email = false
    }
    proxmox = {
      name      = "Proxmox VE"
      redirect  = var.proxmox_ui_urls
      groups    = [authentik_group.proxmox_admins.id]
      scopes    = []
      own_email = false
    }
    # Web sign-in and the mobile apps (which go through ABS's own mobile-redirect, not a custom scheme)
    audiobookshelf = {
      name = "Audiobookshelf"
      redirect = [
        "https://books.${var.base_domain}/auth/openid/callback",
        "https://books.${var.base_domain}/auth/openid/mobile-redirect",
      ]
      groups    = [authentik_group.audiobookshelf_users.id, authentik_group.audiobookshelf_admins.id]
      scopes    = [authentik_property_mapping_provider_scope.abs_roles.id]
      own_email = false
    }
    # Vaultwarden: SSO identifies the user; the master password still decrypts the vault (never sent here).
    # Its own email mapping (verified), offline_access for the refresh token its clients keep. Access tokens
    # stay at the provider default (10 minutes): Vaultwarden's web vault needs more than 5.
    # Headscale (VPN): joining a device is a sign-in here; members of headscale-users only. Headscale names
    # the user after preferred_username, which its ACLs refer to (ansible group_vars/headscale.yml).
    headscale = {
      name      = "Headscale (VPN)"
      redirect  = ["https://hs.${var.base_domain}/oidc/callback"]
      groups    = [authentik_group.headscale_users.id]
      scopes    = []
      own_email = false
    }
    vaultwarden = {
      name      = "Vaultwarden"
      redirect  = ["https://vault.${var.base_domain}/identity/connect/oidc-signin"]
      groups    = [authentik_group.vaultwarden_users.id]
      own_email = true
      scopes    = [authentik_property_mapping_provider_scope.verified_email.id, data.authentik_property_mapping_provider_scope.offline_access.ids[0]]
    }
    # Jellyfin SSO plugin (K0lin fork): web sign-in from outside, which then approves Quick Connect codes for
    # the apps. Same groups as the LDAP outpost (ldap.tf); the plugin maps the profile scope's "groups" claim.
    jellyfin = {
      name      = "Jellyfin"
      redirect  = ["https://media.${var.base_domain}/sso/OID/redirect/authentik"]
      groups    = [authentik_group.jellyfin_users.id, authentik_group.jellyfin_admins.id]
      scopes    = []
      own_email = false
    }
  }
}

resource "authentik_provider_oauth2" "app" {
  for_each = local.oidc_apps

  name        = each.key
  client_id   = each.key
  client_type = "confidential"
  # Proxmox is an admin application: trusted device plus a fresh second factor once device_trust is enforced
  authorization_flow = each.key == "proxmox" ? local.admin_authorization_flow : data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id
  signing_key        = data.authentik_certificate_key_pair.signing.id
  property_mappings = concat(
    each.value.own_email ? data.authentik_property_mapping_provider_scope.oidc_no_email.ids : data.authentik_property_mapping_provider_scope.oidc.ids,
    each.value.scopes,
  )
  grant_types = ["authorization_code", "refresh_token"]
  allowed_redirect_uris = [
    for u in each.value.redirect : { matching_mode = "strict", url = u, redirect_uri_type = "authorization" }
  ]
}

resource "authentik_application" "app" {
  for_each = local.oidc_apps

  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_oauth2.app[each.key].id
}

# Only members of the listed groups may use each application.
resource "authentik_policy_binding" "app_access" {
  for_each = {
    for pair in flatten([
      for app, cfg in local.oidc_apps : [
        for i, g in cfg.groups : { key = "${app}-${i}", app = app, group = g, order = i }
      ]
    ]) : pair.key => pair
  }

  target = authentik_application.app[each.value.app].uuid
  group  = each.value.group
  order  = each.value.order
}
