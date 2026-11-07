# Authentik configuration for prod: everything lives in modules/authentik_config.
module "authentik" {
  source = "../../modules/authentik_config"

  base_domain         = "example.com"
  ldap_outpost_ip     = "__SVC_NET__.11"           # identity host (idp01)
  wazuh_dashboard_url = "https://siem.example.com" # UniFi local DNS record for siem01; reached directly or through the paw01 SOCKS tunnel
  proxmox_ui_urls = [
    "https://pve01.example.com:8006",
    "https://pve02.example.com:8006",
    "https://pve03.example.com:8006",
  ]

  # Registered devices as a sign-in factor (ADR-0006, docs/howto/device-trust.md). Keep in step with
  # device_trust_mode in ansible/inventories/common/group_vars/all/device_trust.yml: off, enroll, enforce.
  device_trust = "enroll"
  # name = { owner = "<authentik username>", key_sha256 = "<bin/device-cert prod enroll prints it>" }
  trusted_devices = {}
}

# 2026-10: the configuration moved from this root into the module. These blocks move the
# existing state; the first plan after the move must show only moves and no changes.
moved {
  from = authentik_group.jellyfin_users
  to   = module.authentik.authentik_group.jellyfin_users
}
moved {
  from = authentik_group.jellyfin_admins
  to   = module.authentik.authentik_group.jellyfin_admins
}
moved {
  from = random_password.jellyfin_ldap_bind
  to   = module.authentik.random_password.jellyfin_ldap_bind
}
moved {
  from = authentik_user.jellyfin_ldap
  to   = module.authentik.authentik_user.jellyfin_ldap
}
moved {
  from = tls_private_key.ldap
  to   = module.authentik.tls_private_key.ldap
}
moved {
  from = tls_self_signed_cert.ldap
  to   = module.authentik.tls_self_signed_cert.ldap
}
moved {
  from = authentik_certificate_key_pair.ldap
  to   = module.authentik.authentik_certificate_key_pair.ldap
}
moved {
  from = authentik_provider_ldap.jellyfin
  to   = module.authentik.authentik_provider_ldap.jellyfin
}
moved {
  from = authentik_application.jellyfin_ldap
  to   = module.authentik.authentik_application.jellyfin_ldap
}
moved {
  from = authentik_policy_binding.jellyfin_ldap_users
  to   = module.authentik.authentik_policy_binding.jellyfin_ldap_users
}
moved {
  from = authentik_policy_binding.jellyfin_ldap_admins
  to   = module.authentik.authentik_policy_binding.jellyfin_ldap_admins
}
moved {
  from = authentik_policy_binding.jellyfin_ldap_svc
  to   = module.authentik.authentik_policy_binding.jellyfin_ldap_svc
}
moved {
  from = authentik_rbac_role.ldap_search
  to   = module.authentik.authentik_rbac_role.ldap_search
}
moved {
  from = authentik_rbac_permission_role.ldap_search
  to   = module.authentik.authentik_rbac_permission_role.ldap_search
}
moved {
  from = authentik_group.ldap_search
  to   = module.authentik.authentik_group.ldap_search
}
moved {
  from = authentik_outpost.ldap
  to   = module.authentik.authentik_outpost.ldap
}
moved {
  from = authentik_group.lab_admins
  to   = module.authentik.authentik_group.lab_admins
}
moved {
  from = authentik_group.forgejo_users
  to   = module.authentik.authentik_group.forgejo_users
}
moved {
  from = authentik_group.forgejo_admins
  to   = module.authentik.authentik_group.forgejo_admins
}
moved {
  from = authentik_group.nextcloud_users
  to   = module.authentik.authentik_group.nextcloud_users
}
moved {
  from = authentik_group.proxmox_admins
  to   = module.authentik.authentik_group.proxmox_admins
}
moved {
  from = authentik_provider_oauth2.app
  to   = module.authentik.authentik_provider_oauth2.app
}
moved {
  from = authentik_application.app
  to   = module.authentik.authentik_application.app
}
moved {
  from = authentik_policy_binding.app_access
  to   = module.authentik.authentik_policy_binding.app_access
}
moved {
  from = authentik_group.proxy
  to   = module.authentik.authentik_group.proxy
}
moved {
  from = authentik_provider_proxy.app
  to   = module.authentik.authentik_provider_proxy.app
}
moved {
  from = authentik_application.proxy
  to   = module.authentik.authentik_application.proxy
}
moved {
  from = authentik_policy_binding.proxy
  to   = module.authentik.authentik_policy_binding.proxy
}
moved {
  from = authentik_outpost.proxy
  to   = module.authentik.authentik_outpost.proxy
}
