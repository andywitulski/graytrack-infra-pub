terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox" }
  }
}

resource "proxmox_virtual_environment_container" "this" {
  description   = "${var.description} Managed by OpenTofu."
  node_name     = var.node
  vm_id         = var.vm_id
  tags          = sort(concat(["tofu", var.env_tag], var.tags))
  unprivileged  = true
  start_on_boot = true
  started       = true
  pool_id       = var.pool_id
  protection    = var.protection

  features {
    nesting = var.nesting
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = 512
  }

  disk {
    datastore_id = var.datastore
    size         = var.disk_gb
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    vlan_id  = var.service_vlan
    firewall = var.firewall
  }

  initialization {
    hostname = var.name

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.service_ipv4
        gateway = var.service_gateway
      }
    }

    user_account {
      keys = [var.ansible_pubkey]
    }
  }

  # Bind mounts, ID maps and device passthrough are root-only in Proxmox.
  # The pve_lxc_host Ansible role manages them; OpenTofu must not fight it.
  # The template and the first-boot root keys are create-time inputs the API cannot report back, and
  # both force a replacement: without them here an import (bin/tf-adopt) or a new template would
  # rebuild every container. SSH access after creation is Ansible's job (ssh_ca, guest_base).
  # pool_id: the provider never reads a container's pool back (bpg/proxmox 0.113, unlike VMs), and it
  # forces a replacement, so every imported container would be rebuilt. The pool is still set at
  # creation; proxmox_virtual_environment_pool.<name>.members shows the real membership.
  lifecycle {
    ignore_changes = [
      mount_point, device_passthrough, idmap,
      operating_system[0].template_file_id, initialization[0].user_account, pool_id,
    ]

    precondition {
      condition     = var.native_vlan == null || var.service_vlan == null || var.service_vlan != var.native_vlan
      error_message = "${var.name}: service_vlan ${coalesce(var.service_vlan, 0)} is the trunk's native VLAN. Set it to null; tagged frames on the native VLAN are dropped."
    }
  }
}
