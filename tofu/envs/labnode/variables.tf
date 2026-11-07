variable "state_passphrase" {
  description = "Passphrase for OpenTofu state and plan encryption (from sops)."
  type        = string
  sensitive   = true
}

variable "pvedev_iso_dir" {
  description = "Directory on the machine running tofu (paw01) holding the dev nodes' auto-install ISOs (playbooks/labnode-dev-isos.yml)."
  type        = string
  default     = "/srv/iso/pvedev"
}

variable "build_dev" {
  description = "Create the dev cluster VMs. Needs their install ISOs in pvedev_iso_dir first, so it starts false."
  type        = bool
  default     = false
}
