variable "state_passphrase" {
  description = "Passphrase for OpenTofu state and plan encryption (from sops)."
  type        = string
  sensitive   = true
}

variable "firewall_enforce" {
  description = "true: drop inbound that no rule covers. false: audit mode (accept and log it), as in tofu/envs/prod."
  type        = bool
  # Enforcing from the first apply: these two guests are new, their clients are known, and they hold
  # every secret and every state file in the lab.
  default = true
}
