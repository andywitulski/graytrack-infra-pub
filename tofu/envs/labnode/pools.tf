resource "proxmox_virtual_environment_pool" "admin" {
  pool_id = "admin"
  comment = "Admin workstation (managed by OpenTofu)"
}

resource "proxmox_virtual_environment_pool" "ai" {
  pool_id = "ai"
  comment = "GPU workloads (managed by OpenTofu)"
}

resource "proxmox_virtual_environment_pool" "dev" {
  pool_id = "dev"
  comment = "Nested dev cluster, managed through inventories/dev (managed by OpenTofu)"
}

resource "proxmox_virtual_environment_pool" "offsec" {
  pool_id = "offsec"
  comment = "Kali on the internet-only kalinet (managed by OpenTofu)"
}
