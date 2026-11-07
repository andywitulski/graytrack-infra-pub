variable "env" {
  description = "Environment name, for descriptions only."
  type        = string
}

variable "controller_cidrs" {
  description = "Where automation logs in from (the Ansible / OpenTofu controller). AppRole secret IDs and the tokens they produce work from these addresses only."
  type        = list(string)
}

variable "secret_id_ttl_seconds" {
  description = "Lifetime of an AppRole secret ID. Re-issue with bin/bao-approle before it runs out."
  type        = number
  default     = 7776000 # 90 days
}

variable "ca_root_pem" {
  description = "Root certificate of ca01 (step-ca). When set, the cert auth method lets the automation identities log in with their short-lived X.509 certificates instead of AppRole secret IDs. null until bin/ca-init has run."
  type        = string
  default     = null
}
