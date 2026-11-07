# Same pools as prod, so permissions and backup selection behave the same.
resource "proxmox_virtual_environment_pool" "services" {
  pool_id = "services"
  comment = "Service VMs behind edge01 (managed by OpenTofu, dev)"
}

resource "proxmox_virtual_environment_pool" "data" {
  pool_id = "data"
  comment = "Containers serving pool data: media, sync, files (managed by OpenTofu, dev)"
}

resource "proxmox_virtual_environment_pool" "security" {
  pool_id = "security"
  comment = "Security monitoring: SIEM and sensors (managed by OpenTofu, dev)"
}
