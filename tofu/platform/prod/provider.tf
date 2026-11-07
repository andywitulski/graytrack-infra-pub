# Endpoint and API token come from PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN
# (decrypted by bin/tf-platform). Nothing secret lives in this file.
provider "proxmox" {
  insecure = false

  ssh {
    agent    = true
    username = "tofu"
  }
}
