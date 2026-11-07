# The secrets this root creates in Authentik go straight to OpenBao, where Ansible reads them
# (docs/howto/secrets-openbao.md). Nobody copies a client secret by hand any more: a new or rotated
# secret is in kv/services/prod/tf-authentik as soon as the apply that made it finishes.
# The field names are the Ansible variable names. secrets/policy.yml (tofu_owned) lists them, so the sops
# tooling leaves them alone.
#
# Address and CA from VAULT_ADDR / VAULT_CACERT (bin/lib/platform.sh), token from VAULT_TOKEN: bin/tf-ak logs
# in as the tf-authentik AppRole, whose policy allows this one path (tofu/modules/openbao_config).
provider "vault" {
  # Same as tofu/openbao: OpenBao reports its own 2.x version, which the provider would misread
  skip_get_vault_version = true
  vault_version_override = "1.14.0"
  skip_child_token       = true # the AppRole token's policy cannot create child tokens
}

resource "vault_kv_secret_v2" "authentik" {
  mount = "kv"
  name  = "services/prod/tf-authentik"
  data_json = jsonencode({
    forgejo_oidc_client_secret        = module.authentik.forgejo_client_secret
    nextcloud_oidc_client_secret      = module.authentik.nextcloud_client_secret
    audiobookshelf_oidc_client_secret = module.authentik.audiobookshelf_client_secret
    vaultwarden_oidc_client_secret    = module.authentik.vaultwarden_client_secret
    headscale_oidc_client_secret      = module.authentik.headscale_client_secret
    proxmox_oidc_client_secret        = module.authentik.proxmox_client_secret
    jellyfin_oidc_client_secret       = module.authentik.jellyfin_client_secret
    jellyfin_ldap_bind_password       = module.authentik.jellyfin_ldap_bind_password
  })
  # Keep only the latest version's data on delete; the kv engine keeps 10 versions of history
  delete_all_versions = true
}
