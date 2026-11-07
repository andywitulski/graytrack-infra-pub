output "forgejo_client_secret" {
  value     = authentik_provider_oauth2.app["forgejo"].client_secret
  sensitive = true
}

output "nextcloud_client_secret" {
  value     = authentik_provider_oauth2.app["nextcloud"].client_secret
  sensitive = true
}

output "proxmox_client_secret" {
  value     = authentik_provider_oauth2.app["proxmox"].client_secret
  sensitive = true
}

output "audiobookshelf_client_secret" {
  value     = authentik_provider_oauth2.app["audiobookshelf"].client_secret
  sensitive = true
}

output "headscale_client_secret" {
  value     = authentik_provider_oauth2.app["headscale"].client_secret
  sensitive = true
}

output "vaultwarden_client_secret" {
  value     = authentik_provider_oauth2.app["vaultwarden"].client_secret
  sensitive = true
}

output "jellyfin_client_secret" {
  value     = authentik_provider_oauth2.app["jellyfin"].client_secret
  sensitive = true
}

output "jellyfin_ldap_bind_password" {
  value     = random_password.jellyfin_ldap_bind.result
  sensitive = true
}

output "ldap_ca_pem" { value = authentik_certificate_key_pair.ldap.certificate_data } # live cert, see ldap.tf
output "ldap_outpost_id" { value = authentik_outpost.ldap.id }
output "proxy_outpost_id" { value = authentik_outpost.proxy.id }

# Public: the identity provider's SAML metadata (entity ID, SSO URL, signing certificate)
output "wazuh_saml_metadata" { value = data.authentik_provider_saml_metadata.wazuh.metadata }
output "fleet_saml_metadata" { value = data.authentik_provider_saml_metadata.fleet.metadata }
