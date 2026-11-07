# Authentik configuration for dev: everything lives in modules/authentik_config.
module "authentik" {
  source = "../../modules/authentik_config"

  base_domain         = "dev.example.com"
  ldap_outpost_ip     = "__DEV_NET__.42"               # identity host (idp01)
  wazuh_dashboard_url = "https://siem.dev.example.com" # UniFi local DNS record for siem01; reached directly or through the paw01 SOCKS tunnel
  proxmox_ui_urls = [
    "https://pvedev1.dev.example.com:8006",
    "https://pvedev2.dev.example.com:8006",
    "https://pvedev3.dev.example.com:8006",
  ]
}
