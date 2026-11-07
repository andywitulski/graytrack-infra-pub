terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.0"
    }
  }

  # State in PostgreSQL on pg01 (tofu/platform/dev), schema "envs". Still encrypted by the block below
  # before it leaves this machine. Connection settings and password come from bin/lib/platform.sh (bin/tf dev).
  backend "pg" {
    schema_name = "envs"
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
