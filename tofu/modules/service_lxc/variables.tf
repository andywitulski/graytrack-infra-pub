variable "name" { type = string }
variable "description" { type = string }
variable "node" { type = string }
variable "vm_id" { type = number }
variable "env_tag" { type = string }
variable "tags" {
  type    = list(string)
  default = []
}
variable "template_file_id" { type = string }
variable "cores" { type = number }
variable "memory_mb" { type = number }
variable "disk_gb" { type = number }
variable "datastore" {
  type    = string
  default = "local-lvm"
}
variable "nesting" {
  type    = bool
  default = true
}
variable "pool_id" {
  type    = string
  default = null
}
variable "service_vlan" {
  type    = number
  default = null
}
variable "service_ipv4" { type = string }
variable "service_gateway" { type = string }
variable "dns_servers" { type = list(string) }
variable "ansible_pubkey" { type = string }
variable "native_vlan" {
  description = "The trunk's untagged VLAN. Guests on it must leave service_vlan null: a tag equal to the native VLAN is dropped by the switch."
  type        = number
  default     = null
}
variable "firewall" {
  description = "Put the service NIC behind the Proxmox guest firewall (rules: tofu/envs/<env>/firewall.tf)."
  type        = bool
  default     = false
}
variable "protection" {
  description = "Proxmox protection flag: the container and its disks cannot be removed until it is cleared (by hand or here). For guests that hold state nothing else can rebuild."
  type        = bool
  default     = false
}
