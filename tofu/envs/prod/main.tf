data "proxmox_virtual_environment_nodes" "all" {}

output "cluster_nodes" {
  description = "Node names reported by the Proxmox API."
  value       = data.proxmox_virtual_environment_nodes.all.names
}
