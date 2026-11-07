terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.0"
    }
  }

  # This root's state lives in the database it creates (pg01). The first build cannot use it yet:
  # bin/tf-platform dev bootstrap applies on local (encrypted) state, then bin/tf-platform dev migrate
  # moves the state into pg01. Connection settings come from bin/lib/platform.sh. docs/howto/platform-tier.md
  backend "pg" {
    schema_name = "platform"
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
