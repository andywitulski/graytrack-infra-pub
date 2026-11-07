variable "base_domain" {
  description = "Public DNS suffix of this environment's services (example.com, dev.example.com)."
  type        = string
}

variable "proxmox_ui_urls" {
  description = "Proxmox web UI URLs allowed as OIDC redirects."
  type        = list(string)
}

variable "ldap_outpost_ip" {
  description = "Address of the identity host; the LDAPS certificate is issued for it."
  type        = string
}

variable "ldap_base_dn" {
  type    = string
  default = "dc=ldap,dc=labstack,dc=net"
}

variable "wazuh_dashboard_url" {
  description = "Wazuh dashboard URL as users open it (no trailing slash); the SAML ACS lives under it."
  type        = string
}

variable "step_ca_oidc_listen" {
  description = "Loopback address the step CLI listens on for the Authentik callback (roles/step_ca step_ca_oidc_listen)."
  type        = string
  default     = "127.0.0.1:10000"
}

variable "device_trust" {
  description = <<-EOT
    Registered devices as an authentication factor (device_trust.tf, ADR-0006):
      off      nothing is created
      enroll   device certificates can be issued (step-ca-device, fresh MFA); sign-in unchanged
      enforce  a registered device replaces the second factor at sign-in, and admin applications
               (Proxmox, Wazuh, Fleet, SSH certificates) require a registered device plus a fresh second factor
    Set the same value as device_trust_mode in the Ansible inventory (caddy, step_ca).
  EOT
  type        = string
  default     = "off"

  validation {
    condition     = contains(["off", "enroll", "enforce"], var.device_trust)
    error_message = "device_trust is off, enroll or enforce."
  }
}

variable "trusted_devices" {
  description = <<-EOT
    Registered devices: name => { owner = Authentik username, key_sha256 = SHA-256 (hex) of the device
    certificate's public key, as bin/device-cert prints it }. Public data: a hash of a public key.
    Removing an entry takes the device out of sign-in at the next apply, whatever its certificate says.
  EOT
  type = map(object({
    owner      = string
    key_sha256 = string
    kind       = optional(string, "workstation") # workstation (Secure Enclave or TPM key), for the record
  }))
  default = {}

  validation {
    condition     = alltrue([for d in values(var.trusted_devices) : can(regex("^[0-9a-fA-F]{64}$", d.key_sha256))])
    error_message = "key_sha256 is 64 hex characters (bin/device-cert <env> enroll prints it)."
  }
}
