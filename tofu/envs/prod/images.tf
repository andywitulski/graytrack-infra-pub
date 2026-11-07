locals {
  pve_nodes  = ["pve01", "pve02", "pve03"]
  image_base = "cloud.debian.org/images/cloud/trixie/latest"
  image_file = "debian-13-genericcloud-amd64"
}

resource "proxmox_download_file" "debian13" {
  for_each     = toset(local.pve_nodes)
  node_name    = each.key
  datastore_id = "local"
  content_type = "iso"
  url          = "https://${local.image_base}/${local.image_file}.qcow2"
  file_name    = "${local.image_file}.img"
  overwrite    = false
}

resource "proxmox_virtual_environment_file" "vendor_data" {
  for_each     = toset(local.pve_nodes)
  node_name    = each.key
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    file_name = "labstack-vendor-data.yaml"
    data      = <<-EOT
      #cloud-config
      package_update: true
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOT
  }
}
