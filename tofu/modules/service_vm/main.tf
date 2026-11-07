terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name          = var.name
  description   = "${var.description} Managed by OpenTofu."
  node_name     = var.node
  vm_id         = var.vm_id
  tags          = concat(["tofu", var.env_tag], var.tags)
  pool_id       = var.pool_id
  on_boot       = true
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
    timeout = "5m"
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore
    file_id      = var.image_file_id
    interface    = "scsi0"
    size         = var.disk_gb
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge   = "vmbr0"
    vlan_id  = var.service_vlan
    firewall = var.firewall
  }

  dynamic "network_device" {
    for_each = var.storage_bridge == null ? [] : [1]
    content {
      bridge = var.storage_bridge
    }
  }

  serial_device {
    device = "socket"
  }

  # vTPM (ADR-0006). datastore_id is explicit: the provider's default (local-lvm) does not exist on every
  # node, and a failed TPM create on a stopped VM has destroyed VMs before (bpg issue 1640).
  dynamic "tpm_state" {
    for_each = var.vtpm ? [1] : []
    content {
      datastore_id = var.datastore
      version      = "v2.0"
    }
  }

  lifecycle {
    # Create-time inputs the API cannot report back (which image a disk came from, which snippet first
    # boot used). Both force a replacement, so without this an import (bin/tf-adopt) or a new image
    # download would rebuild every VM. A changed image or snippet applies to new VMs only.
    # agent timeout: how long OpenTofu waits for the guest agent, never stored in Proxmox (an import reads
    # the provider default, 15m). Any change to the agent block makes the provider reboot the VM
    # (reboot_after_update), so a mismatch here would reboot every imported VM for nothing.
    ignore_changes = [disk[0].file_id, initialization[0].vendor_data_file_id, agent[0].timeout]

    precondition {
      condition     = var.native_vlan == null || var.service_vlan == null || var.service_vlan != var.native_vlan
      error_message = "${var.name}: service_vlan ${coalesce(var.service_vlan, 0)} is the trunk's native VLAN. Set it to null; tagged frames on the native VLAN are dropped."
    }
  }

  initialization {
    datastore_id        = var.datastore
    vendor_data_file_id = var.vendor_data_file_id

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.service_ipv4
        gateway = var.service_gateway
      }
    }

    dynamic "ip_config" {
      for_each = var.storage_bridge == null ? [] : [1]
      content {
        ipv4 {
          address = var.storage_ipv4
        }
      }
    }

    user_account {
      username = "ansible"
      keys     = [var.ansible_pubkey]
    }
  }
}
