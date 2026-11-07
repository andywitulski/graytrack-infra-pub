# The nested dev cluster (pvedev1-3). Hardware comes from the same file the ISO build reads, so names,
# MACs and sizes are typed once: ansible/inventories/labnode/group_vars/all/pvedev.yml.
# Each node installs itself unattended from its own ISO (built on paw01 by playbooks/labnode-dev-isos.yml)
# and is then managed through inventories/dev like before.

locals {
  pvedev     = yamldecode(file("${path.module}/../../../ansible/inventories/labnode/group_vars/all/pvedev.yml"))
  pvedev_vms = var.build_dev ? { for i, n in local.pvedev.pvedev_nodes : n.name => merge(n, { vm_id = local.pvedev.pvedev_vm_id_base + i + 1 }) } : {}
}

resource "proxmox_virtual_environment_file" "pvedev_iso" {
  for_each     = local.pvedev_vms
  node_name    = local.node
  datastore_id = "local"
  content_type = "iso"

  source_file {
    path = "${var.pvedev_iso_dir}/${each.key}-auto.iso"
  }
}

resource "proxmox_virtual_environment_vm" "pvedev" {
  for_each = local.pvedev_vms

  name        = each.key
  description = "Dev cluster node (nested Proxmox), managed through inventories/dev. Managed by OpenTofu."
  node_name   = local.node
  vm_id       = each.value.vm_id
  tags        = ["tofu", "env-dev", "pvedev"]
  pool_id     = proxmox_virtual_environment_pool.dev.pool_id
  on_boot     = true
  # Empty disk on first boot falls through to the installer ISO; afterwards the installed system boots
  boot_order = ["virtio0", "ide2"]

  agent {
    enabled = false
  }

  cpu {
    cores = local.pvedev.pvedev_vcpus
    type  = "host" # nested virtualization
  }

  memory {
    dedicated = each.value.memory_gib * 1024
  }

  # virtio-blk, so the installer sees /dev/vda (answer.toml) and data disks keep their by-id names
  disk {
    datastore_id = local.datastore
    interface    = "virtio0"
    size         = each.value.disk_gib
    discard      = "on"
    file_format  = "raw"
  }

  dynamic "disk" {
    for_each = each.value.data_disks
    content {
      datastore_id = local.datastore
      interface    = "virtio${disk.key + 1}"
      size         = local.pvedev.pvedev_data_disk_gib
      serial       = disk.value # /dev/disk/by-id/virtio-tank0 ... (zfs_host_pool in host_vars/pvedev3.yml)
      discard      = "on"
      file_format  = "raw"
    }
  }

  cdrom {
    interface = "ide2"
    file_id   = proxmox_virtual_environment_file.pvedev_iso[each.key].id
  }

  network_device {
    bridge      = proxmox_sdn_vnet.pvedev.id
    mac_address = upper(each.value.mac)
  }

  network_device {
    bridge      = proxmox_sdn_vnet.pvedevst.id
    mac_address = upper(each.value.storage_mac)
  }

  serial_device {
    device = "socket"
  }

  lifecycle {
    ignore_changes = [cdrom] # the ISO can be removed by hand after the install
  }

  depends_on = [proxmox_sdn_applier.labnode]
}
