variable "state_passphrase" {
  description = "Passphrase for OpenTofu state and plan encryption (from sops)."
  type        = string
  sensitive   = true
}
