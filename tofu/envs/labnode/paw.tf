# paw01: the admin workstation and second controller (the admin workstation is the other). Its address is unifi_paw
# in ansible/network/zone_policy.yml, which the UniFi policies, the Proxmox ipsets and pg01 all trust.
# NICs (cloud-init ip_config is matched in this order):
#   net0 Management  __MGMT_NET__.30  untagged on vmbr0 (the trunk's native VLAN): lab, GitHub over HTTPS
#   net1 pvedev      __DEV_NET__.2       the nested dev cluster (reachable from here only)
#   net2 vmbrtb      __TB_NET__.2/30    direct Thunderbolt cable to the workstation (__TB_NET__.1); no gateway, and the
#                                    node has no address on the bridge (roles/lab_node)
# Changing NICs or ip_config gives cloud-init a new instance-id: it re-runs on the next boot. guest_base keeps
# the SSH host keys (ssh_deletekeys false), so the host certificate stays valid.

resource "proxmox_virtual_environment_vm" "paw01" {
  name          = "paw01"
  description   = "Admin workstation (repo, sops, tofu, ansible). Managed by OpenTofu."
  node_name     = local.node
  vm_id         = 5001
  tags          = ["tofu", "env-labnode", "admin"]
  pool_id       = proxmox_virtual_environment_pool.admin.pool_id
  on_boot       = true
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
    timeout = "5m"
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
    file_id      = proxmox_download_file.debian13.id
    interface    = "scsi0"
    size         = 64
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge = "vmbr0"
  }

  network_device {
    bridge = proxmox_sdn_vnet.pvedev.id
  }

  network_device {
    bridge = "vmbrtb"
  }

  serial_device {
    device = "socket"
  }

  # vTPM (ADR-0006): the node's swtpm creates it with an EK certificate; roles/tpm records and pins it.
  # Adding it stops and starts the VM (the provider does it). datastore_id explicit (bpg issue 1640).
  tpm_state {
    datastore_id = local.datastore
    version      = "v2.0"
  }

  initialization {
    datastore_id        = local.datastore
    vendor_data_file_id = proxmox_virtual_environment_file.vendor_data.id

    dns {
      servers = [local.mgmt_gw]
    }

    ip_config {
      ipv4 {
        address = "${local.zp.unifi_paw}/24"
        gateway = local.mgmt_gw
      }
    }

    ip_config {
      ipv4 {
        address = "__DEV_NET__.2/24"
      }
    }

    ip_config {
      ipv4 {
        address = "__TB_NET__.2/30"
      }
    }

    user_account {
      username = "ansible"
      keys     = [local.ansible_pubkey]
    }
  }

  depends_on = [proxmox_sdn_applier.labnode]
}

output "paw01_address" {
  value = local.zp.unifi_paw
}
