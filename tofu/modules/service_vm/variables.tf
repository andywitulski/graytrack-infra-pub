variable "name" { type = string }
variable "description" { type = string }
variable "node" { type = string }
variable "vm_id" { type = number }
variable "env_tag" { type = string }
variable "tags" {
  type    = list(string)
  default = []
}
variable "cores" { type = number }
variable "memory_mb" { type = number }
variable "disk_gb" { type = number }
variable "datastore" {
  type    = string
  default = "local-lvm"
}
variable "image_file_id" { type = string }
variable "service_vlan" {
  type    = number
  default = null
}
variable "service_ipv4" { type = string }
variable "service_gateway" { type = string }
variable "storage_bridge" {
  type    = string
  default = null
}
variable "storage_ipv4" {
  type    = string
  default = null
}
variable "dns_servers" { type = list(string) }
variable "ansible_pubkey" { type = string }
variable "vendor_data_file_id" {
  type    = string
  default = null
}
variable "pool_id" {
  type    = string
  default = null
}
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
variable "vtpm" {
  description = <<-EOT
    Give the VM a TPM 2.0 (Proxmox swtpm, state on the VM's datastore). Adding or removing it stops and
    starts the VM (the provider does it), so roll it out one VM at a time (docs/howto/device-trust.md).
    The node's swtpm local CA signs the EK certificate; roles/tpm records and pins it (ADR-0006).
  EOT
  type        = bool
  default     = false
}
