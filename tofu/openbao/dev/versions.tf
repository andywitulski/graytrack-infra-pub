terraform {
  required_version = ">= 1.10.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13"
    }
  }

  # State in PostgreSQL on pg01 (tofu/platform/dev), schema "openbao". Connection settings and password
  # come from bin/lib/platform.sh (bin/tf-bao dev).
  backend "pg" {
    schema_name = "openbao"
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
