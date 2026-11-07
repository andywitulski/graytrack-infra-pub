# The secrets below are also written to OpenBao by openbao.tf (kv/services/prod/tf-authentik), which is
# where Ansible reads them: nothing to copy by hand. The outputs stay for inspection and for dev, which has
# no OpenBao (there: V=$(bin/tf-ak dev output -raw ...); sops set ...; unset V).
# The LDAPS CA is public; it goes into the inventory for the media role:
#   bin/tf-ak prod output -raw ldap_ca_pem > ansible/files/prod/ldap-outpost-ca.pem
# Same for the Wazuh SAML metadata (public):
#   bin/tf-ak prod output -raw wazuh_saml_metadata > ansible/files/prod/wazuh-saml-metadata.xml
output "forgejo_client_secret" {
  value     = module.authentik.forgejo_client_secret
  sensitive = true
}

output "nextcloud_client_secret" {
  value     = module.authentik.nextcloud_client_secret
  sensitive = true
}

output "proxmox_client_secret" {
  value     = module.authentik.proxmox_client_secret
  sensitive = true
}

output "audiobookshelf_client_secret" {
  value     = module.authentik.audiobookshelf_client_secret
  sensitive = true
}

output "jellyfin_client_secret" {
  value     = module.authentik.jellyfin_client_secret
  sensitive = true
}

output "jellyfin_ldap_bind_password" {
  value     = module.authentik.jellyfin_ldap_bind_password
  sensitive = true
}

output "ldap_ca_pem" { value = module.authentik.ldap_ca_pem }
output "ldap_outpost_id" { value = module.authentik.ldap_outpost_id }
output "proxy_outpost_id" { value = module.authentik.proxy_outpost_id }
output "wazuh_saml_metadata" { value = module.authentik.wazuh_saml_metadata }
# Fleet console SSO; bin/fleet-gitops reads it
output "fleet_saml_metadata" { value = module.authentik.fleet_saml_metadata }
