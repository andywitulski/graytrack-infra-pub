terraform {
  required_version = ">= 1.10.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.70"
    }
  }

  # State in PostgreSQL on pg01, its own schema so it never touches the Proxmox state in "envs".
  # Connection and passphrase come from bin/lib/platform.sh (bin/tf-cloud prod), same as the other roots.
  backend "pg" {
    schema_name = "cloud"
  }

  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }
    state {
      method   = method.aes_gcm.main
      enforced = true
    }
    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}
