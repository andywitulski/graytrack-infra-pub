resource "proxmox_virtual_environment_pool" "services" {
  pool_id = "services"
  comment = "Service VMs behind edge01 (managed by OpenTofu)"
}

resource "proxmox_virtual_environment_pool" "data" {
  pool_id = "data"
  comment = "Containers serving pool data: media, sync, files (managed by OpenTofu)"
}
