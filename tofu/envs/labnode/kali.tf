# kali01: Kali on kalinet (network.tf), installed by hand from the ISO on the console. Internet only:
# the node drops kalinet traffic to every private range and to itself except DNS and DHCP, and its DNS
# withholds the lab's names (roles/lab_node). Out through the node's NAT, so UniFi sees it as the node
# and allows what Management may do externally: HTTP and HTTPS.
# Not managed by Ansible, no SSH certificate, no Wazuh agent, no PBS backup: rebuilt, never restored.
#
# Settings here, committed, rather than -var flags: a later plain `bin/tf labnode apply` must not destroy
# kali01. The checksum is public; take it from SHA256SUMS only after its signature checks out
# (docs/howto/lab-node.md, step 13). A new release: eject the ISO from kali01 first (Hardware,
# CD/DVD Drive, "Do not use any media"), then change both here and apply; the old ISO is deleted.

locals {
  kali_build   = true                                                               # true once kali_sha256 is filled in
  kali_release = "2026.3"                                                           # cdimage.kali.org/kali-<release>/
  kali_sha256  = "db9cbed33edb45727d16911813c2434fcd1419585007884153be22a03b30ec2f" # sha256 of kali-linux-<release>-installer-amd64.iso, lowercase hex
  kali_iso     = "kali-linux-${local.kali_release}-installer-amd64.iso"
}

resource "proxmox_download_file" "kali" {
  count              = local.kali_build ? 1 : 0
  node_name          = local.node
  datastore_id       = "local"
  content_type       = "iso"
  url                = "https://cdimage.kali.org/kali-${local.kali_release}/${local.kali_iso}"
  file_name          = local.kali_iso
  checksum           = local.kali_sha256
  checksum_algorithm = "sha256"
  upload_timeout     = 3600 # about 4 GB
  overwrite          = false

  lifecycle {
    precondition {
      condition     = can(regex("^[0-9a-f]{64}$", local.kali_sha256))
      error_message = "Set kali_sha256 in kali.tf (lowercase hex) from the signed SHA256SUMS of Kali ${local.kali_release}."
    }
  }
}

resource "proxmox_virtual_environment_vm" "kali01" {
  count         = local.kali_build ? 1 : 0
  name          = "kali01"
  description   = "Kali, internet only (kalinet). Installed by hand from the ISO. Managed by OpenTofu."
  node_name     = local.node
  vm_id         = 5021
  tags          = ["tofu", "env-labnode", "offsec"]
  pool_id       = proxmox_virtual_environment_pool.offsec.pool_id
  on_boot       = false # started by hand when needed
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0", "ide2"] # the empty disk falls through to the installer once

  # No guest agent until one is installed in Kali; then enable it here (that change reboots the VM)
  agent {
    enabled = false
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = local.datastore
    interface    = "scsi0"
    size         = 80
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  cdrom {
    file_id   = proxmox_download_file.kali[0].id
    interface = "ide2"
  }

  network_device {
    bridge = proxmox_sdn_vnet.kalinet.id
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [cdrom] # ejecting the ISO after the install is not drift
  }

  depends_on = [proxmox_sdn_applier.labnode]
}
