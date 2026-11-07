locals {
  image_base = "cloud.debian.org/images/cloud/trixie/latest"
  image_file = "debian-13-genericcloud-amd64"
  # gpu01 needs the full kernel (DRM, PCI drivers) for the NVIDIA driver; same cloud-init
  image_file_generic = "debian-13-generic-amd64"
}

resource "proxmox_download_file" "debian13" {
  node_name    = local.node
  datastore_id = "local"
  content_type = "iso"
  url          = "https://${local.image_base}/${local.image_file}.qcow2"
  file_name    = "${local.image_file}.img"
  overwrite    = false
}

resource "proxmox_download_file" "debian13_generic" {
  node_name    = local.node
  datastore_id = "local"
  content_type = "iso"
  url          = "https://${local.image_base}/${local.image_file_generic}.qcow2"
  file_name    = "${local.image_file_generic}.img"
  overwrite    = false
}

resource "proxmox_virtual_environment_file" "vendor_data" {
  node_name    = local.node
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
