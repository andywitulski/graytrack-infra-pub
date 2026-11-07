terraform {
  required_version = ">= 1.8"

  required_providers {
    authentik = {
      source = "goauthentik/authentik"
      # Pin to the provider release matching the Authentik server version you deploy.
      version = "2026.8"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State in PostgreSQL on pg01 (tofu/platform/dev), schema "authentik". Still encrypted by the block below
  # before it leaves this machine. Connection settings and password come from bin/lib/platform.sh (bin/tf-ak dev).
  backend "pg" {
    schema_name = "authentik"
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

# url and token come from AUTHENTIK_URL and AUTHENTIK_TOKEN (bin/tf-ak loads them from sops)
provider "authentik" {}
