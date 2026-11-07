# ldap.tf - Authentik LDAP outpost for Jellyfin (TV and phone apps need username/password)

resource "authentik_group" "jellyfin_users" { name = "jellyfin_users" }
resource "authentik_group" "jellyfin_admins" { name = "jellyfin_admins" }

# Service account Jellyfin binds with to look users up
# ignore_changes = all: the password is generated once. An adopted state imports the live value from
# sops (an import marks every character class "true", which would otherwise force a new password);
# rotate on purpose with -replace.
resource "random_password" "jellyfin_ldap_bind" {
  length  = 40
  special = false

  lifecycle {
    ignore_changes = all
  }
}

resource "authentik_user" "jellyfin_ldap" {
  username = "svc-jellyfin-ldap"
  name     = "Jellyfin LDAP bind"
  type     = "service_account"
  groups   = [authentik_group.ldap_search.id]
  password = random_password.jellyfin_ldap_bind.result
}

# TLS for LDAPS: a self-signed cert for the identity host's address, trusted on the media host by Ansible
resource "tls_private_key" "ldap" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ldap" {
  private_key_pem       = tls_private_key.ldap.private_key_pem
  validity_period_hours = 24 * 365 * 3
  ip_addresses          = [var.ldap_outpost_ip]
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth", "cert_signing"]
  is_ca_certificate     = true
  subject { common_name = "labstack LDAP outpost" }
}

# The tls_* resources only seed a new keypair. Authentik's copy is the truth: an adopted state reads the
# live certificate and key on import, while tls_* hold a fresh pair that was never deployed, so a
# difference must not rotate the cert Jellyfin trusts. ldap_ca_pem is read from here for the same reason.
# Rotate on purpose: -replace on tls_private_key.ldap and this resource, then redeploy the CA (media role).
resource "authentik_certificate_key_pair" "ldap" {
  name             = "ldap-outpost"
  certificate_data = tls_self_signed_cert.ldap.cert_pem
  key_data         = tls_private_key.ldap.private_key_pem

  lifecycle {
    ignore_changes = [certificate_data, key_data]
  }
}

resource "authentik_provider_ldap" "jellyfin" {
  name        = "jellyfin-ldap"
  base_dn     = var.ldap_base_dn
  bind_flow   = data.authentik_flow.authentication.id
  unbind_flow = data.authentik_flow.invalidation.id
  certificate = authentik_certificate_key_pair.ldap.id
  search_mode = "cached"
  bind_mode   = "cached"
}

resource "authentik_application" "jellyfin_ldap" {
  name              = "Jellyfin (LDAP)"
  slug              = "jellyfin-ldap"
  protocol_provider = authentik_provider_ldap.jellyfin.id
}

# Who may bind at all: Jellyfin users, admins, and the service account
resource "authentik_policy_binding" "jellyfin_ldap_users" {
  target = authentik_application.jellyfin_ldap.uuid
  group  = authentik_group.jellyfin_users.id
  order  = 0
}
resource "authentik_policy_binding" "jellyfin_ldap_admins" {
  target = authentik_application.jellyfin_ldap.uuid
  group  = authentik_group.jellyfin_admins.id
  order  = 1
}
resource "authentik_policy_binding" "jellyfin_ldap_svc" {
  target = authentik_application.jellyfin_ldap.uuid
  user   = authentik_user.jellyfin_ldap.id
  order  = 2
}

# The service account may search the whole directory (lookups for every user)
resource "authentik_rbac_role" "ldap_search" {
  name = "ldap-search-full-directory"
}

resource "authentik_rbac_permission_role" "ldap_search" {
  role       = authentik_rbac_role.ldap_search.id
  model      = "authentik_providers_ldap.ldapprovider"
  permission = "authentik_providers_ldap.search_full_directory"
  object_id  = authentik_provider_ldap.jellyfin.id
}

resource "authentik_group" "ldap_search" {
  name  = "svc_ldap_search"
  roles = [authentik_rbac_role.ldap_search.id]
}

resource "authentik_outpost" "ldap" {
  name               = "ldap"
  type               = "ldap"
  protocol_providers = [authentik_provider_ldap.jellyfin.id]
}
