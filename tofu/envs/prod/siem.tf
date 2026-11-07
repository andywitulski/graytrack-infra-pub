resource "proxmox_virtual_environment_pool" "security" {
  pool_id = "security"
  comment = "Security monitoring: SIEM and sensors (managed by OpenTofu)"
}

module "siem01" {
  source = "../../modules/service_vm"

  name                = "siem01"
  description         = "Wazuh SIEM (manager, indexer, dashboard)."
  node                = "pve01"
  vm_id               = 4001
  env_tag             = "env-prod"
  tags                = ["security"]
  pool_id             = proxmox_virtual_environment_pool.security.pool_id
  cores               = 4
  memory_mb           = 12288
  disk_gb             = 150
  image_file_id       = proxmox_download_file.debian13["pve01"].id
  vendor_data_file_id = proxmox_virtual_environment_file.vendor_data["pve01"].id
  service_vlan        = 110
  native_vlan         = local.native_vlan
  service_ipv4        = "__SEC_NET__.10/24"
  service_gateway     = "__SEC_NET__.1"
  dns_servers         = ["__SEC_NET__.1"]
  ansible_pubkey      = local.ansible_pubkey
  firewall            = true
  vtpm                = true # ADR-0006; apply one VM at a time (stop/start)
}

output "siem01_address" {
  value = module.siem01.service_ipv4
}
