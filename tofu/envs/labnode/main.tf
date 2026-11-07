# labnode: standalone Proxmox node on the repurposed workstation (not part of the prod cluster), on the Management
# VLAN like pve01-03 (its switch port uses the "Node trunk" profile, ansible/network/switching.yml).
# Guests: paw01 (admin workstation, Management), gpu01 (ollama on the discrete GPU, Services), pvedev1-3
# (nested dev cluster on the pvedev SDN network). Addresses: ansible/network/zone_policy.yml.
# Node preparation (lab storage, IOMMU, the "gpu0" PCI mapping, dev DNS) is Ansible: playbooks/labnode.yml.

locals {
  node           = "labnode"
  datastore      = "lab" # LVM-thin on the 2TB NVMe, created by playbooks/labnode.yml
  ansible_pubkey = trimspace(file("${path.module}/../../../ansible/files/pubkeys/ansible.pub"))
  zp             = yamldecode(file("${path.module}/../../../ansible/network/zone_policy.yml"))
  mgmt_gw        = "__MGMT_NET__.1"
  services_gw    = "__SVC_NET__.1"
  services_vlan  = 120
}

data "proxmox_virtual_environment_nodes" "all" {}

output "nodes" {
  description = "Node names reported by the Proxmox API (must contain labnode)."
  value       = data.proxmox_virtual_environment_nodes.all.names
}
