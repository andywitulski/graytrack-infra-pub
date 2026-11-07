# OpenBao configuration as code: secrets engine, policies, machine identities.
# Audit devices are not here: OpenBao only accepts them from its config file (ansible role openbao), so a
# token with sys/audit access cannot turn auditing off or point it at a file of its choosing.
#
# Layout of the kv engine (paths are the contract with the consumers, docs/howto/secrets-openbao.md):
#   kv/services/<env>/<service>       service secrets; Ansible reads every one of an environment at the
#                                     start of a run (ansible/plugins/vars/labstack_openbao.py)
#   kv/services/<env>/tf-authentik    the part OpenTofu writes (OIDC client secrets, LDAP bind password)
#   kv/tofu/<root>                    inputs for OpenTofu roots, read through the tofu identity
#
# Machine identities log in two ways, same policies: AppRole (secret ID in sops, 90 days) and, once ca01
# exists, cert auth (an 8 h X.509 client certificate from ca01, nothing stored). bin/ap picks one through
# PLATFORM_BAO_AUTH; AppRole stays as the fallback for when ca01 is down.
#
# Tier 0 stays in sops on purpose: what is needed to build or recover this platform (Proxmox API token,
# state passphrase, database passwords, OpenBao's seal key and recovery keys) cannot live inside it.

resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  options     = { version = "2" }
  description = "Service and automation secrets (${var.env}). Managed by OpenTofu."
}

resource "vault_kv_secret_backend_v2" "kv" {
  mount                = vault_mount.kv.path
  max_versions         = 10
  delete_version_after = 0
  cas_required         = false
}

resource "vault_auth_backend" "approle" {
  type        = "approle"
  path        = "approle"
  description = "Machine identities for automation (${var.env}). Managed by OpenTofu."
}

# ---------------------------------------------------------------- policies
resource "vault_policy" "admin" {
  name   = "platform-admin"
  policy = <<-EOT
    # People who run the platform. Root-equivalent by design; hand it out through an auth method that
    # maps a group (OIDC via Authentik), never as a long-lived token.
    path "*" {
      capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
    }
  EOT
}

resource "vault_policy" "ansible" {
  name   = "ansible"
  policy = <<-EOT
    # Ansible reads service secrets. Read only: seeding and rotation go through people (or bin/bao-*).
    path "${vault_mount.kv.path}/data/services/*" {
      capabilities = ["read"]
    }
    path "${vault_mount.kv.path}/metadata/services/*" {
      capabilities = ["read", "list"]
    }
    path "${vault_mount.kv.path}/metadata/services" {
      capabilities = ["list"]
    }
  EOT
}

resource "vault_policy" "tofu" {
  name   = "tofu"
  policy = <<-EOT
    # OpenTofu roots read their inputs. Nothing else, so a leaked tofu token cannot read service secrets.
    path "${vault_mount.kv.path}/data/tofu/*" {
      capabilities = ["read"]
    }
    path "${vault_mount.kv.path}/metadata/tofu/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "tf_authentik" {
  name   = "tf-authentik"
  policy = <<-EOT
    # tofu/authentik/<env> writes the secrets it creates in Authentik (OIDC client secrets, the Jellyfin
    # LDAP bind password) to one path per environment, and may read them back (the provider refreshes).
    # Nothing else: no other service's secrets, no listing.
    path "${vault_mount.kv.path}/data/services/+/tf-authentik" {
      capabilities = ["create", "read", "update", "delete"]
    }
    # The provider writes the secret's metadata (custom_metadata, max_versions) on every update
    path "${vault_mount.kv.path}/metadata/services/+/tf-authentik" {
      capabilities = ["create", "read", "update", "delete"]
    }
  EOT
}

# ---------------------------------------------------------------- machine identities
# Role IDs are not secret (outputs below). Secret IDs are never created here, so they never sit in state:
# bin/bao-approle issues one and stores it in sops.
locals {
  # Identities that also log in with an X.509 certificate from ca01 (cert auth below)
  cert_roles = {
    ansible = vault_policy.ansible.name
    tofu    = vault_policy.tofu.name
  }
  # AppRole for all of them; tf-authentik has no ca01 certificate profile, so AppRole only
  approles = merge(local.cert_roles, {
    tf-authentik = vault_policy.tf_authentik.name
  })
}

resource "vault_approle_auth_backend_role" "this" {
  for_each = local.approles

  backend               = vault_auth_backend.approle.path
  role_name             = each.key
  token_policies        = [each.value]
  token_ttl             = 1800
  token_max_ttl         = 3600
  token_bound_cidrs     = var.controller_cidrs
  secret_id_bound_cidrs = var.controller_cidrs
  secret_id_ttl         = var.secret_id_ttl_seconds
  secret_id_num_uses    = 0
}

# ---------------------------------------------------------------- cert auth (X.509 from ca01)
# A certificate is accepted when it chains to ca01's root and its common name is the role's own name.
# ca01 only issues those names through the matching JWK provisioner (roles/step_ca templates), and only to
# whoever holds that provisioner's password (sops). Logins are bound to the controller's address as well.
resource "vault_auth_backend" "cert" {
  count = var.ca_root_pem == null ? 0 : 1

  type        = "cert"
  path        = "cert"
  description = "Machine identities with X.509 client certificates from ca01 (${var.env}). Managed by OpenTofu."
}

resource "vault_cert_auth_backend_role" "this" {
  for_each = var.ca_root_pem == null ? {} : local.cert_roles

  backend              = vault_auth_backend.cert[0].path
  name                 = each.key
  display_name         = each.key
  certificate          = var.ca_root_pem
  allowed_common_names = [each.key]
  token_policies       = [each.value]
  token_ttl            = 1800
  token_max_ttl        = 3600
  token_bound_cidrs    = var.controller_cidrs
}
