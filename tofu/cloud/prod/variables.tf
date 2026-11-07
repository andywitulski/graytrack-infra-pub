variable "state_passphrase" {
  description = "Encrypts the OpenTofu state before it leaves this machine (TF_VAR_state_passphrase, sops)."
  type        = string
  sensitive   = true
}

variable "base_domain" {
  description = "The mail domain. The server is mail.<base_domain>, and that is its PTR."
  type        = string
  default     = "example.com"
}

variable "server_type" {
  description = "Hetzner server type. CAX11 is Ampere ARM64 (~EUR 4/mo); Stalwart ships arm64."
  type        = string
  default     = "cax11"
}

variable "location" {
  description = "Hetzner location. US for US recruiters: ash (Ashburn, VA) or hil (Hillsboro, OR)."
  type        = string
  default     = "ash"
}

variable "tailscale_authkey" {
  description = <<-EOT
    A single-use Headscale pre-auth key so the server joins the tailnet on first boot and never needs public
    SSH. Make it on hs01 (docs/howto/mail-public-edge.md); from secrets/cloud-prod.enc.env (TF_VAR_tailscale_authkey).
  EOT
  type        = string
  sensitive   = true
  default     = ""
}
