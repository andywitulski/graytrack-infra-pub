# gpu01: ollama on the discrete GPU (PCI passthrough through the "gpu0" resource mapping, created by
# playbooks/labnode.yml from what lspci reports, so no PCI address is typed here).
# On the Services VLAN next to ai01 (unifi_gpu in ansible/network/zone_policy.yml): the controllers reach
# it for Ansible and the Ollama API through the same zone policies as ai01.

resource "proxmox_virtual_environment_vm" "gpu01" {
  name          = "gpu01"
  description   = "Ollama on the passed-through discrete GPU. Managed by OpenTofu."
  node_name     = local.node
  vm_id         = 5011
  tags          = ["tofu", "env-labnode", "gpu"]
  pool_id       = proxmox_virtual_environment_pool.ai.pool_id
  on_boot       = true
  machine       = "q35" # PCIe passthrough
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
    timeout = "5m"
  }

  cpu {
    cores = 8
    type  = "host"
  }

  # Passthrough pins all guest memory; no ballooning
  memory {
    dedicated = 32768
  }

  disk {
    datastore_id = local.datastore
    file_id      = proxmox_download_file.debian13_generic.id
    interface    = "scsi0"
    size         = 300 # system, the rag database and its nightly dumps (all in the PBS backup)
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  # Ollama's models: re-downloadable, so left out of the PBS backup. roles/ollama finds the disk by its
  # serial, formats it once and mounts it at /var/lib/ollama/models.
  disk {
    datastore_id = local.datastore
    interface    = "scsi1"
    size         = 256
    serial       = "ollama-models"
    backup       = false
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  hostpci {
    device  = "hostpci0"
    mapping = "gpu0"
    pcie    = true
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = local.services_vlan
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
      servers = [local.services_gw]
    }

    ip_config {
      ipv4 {
        address = "${local.zp.unifi_gpu}/24"
        gateway = local.services_gw
      }
    }

    user_account {
      username = "ansible"
      keys     = [local.ansible_pubkey]
    }
  }

  depends_on = [proxmox_sdn_applier.labnode]
}
