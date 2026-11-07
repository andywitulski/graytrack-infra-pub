output "kv_mount" {
  value = vault_mount.kv.path
}

output "approle_role_ids" {
  description = "Not secret: a role ID is useless without a secret ID."
  value       = { for k, r in vault_approle_auth_backend_role.this : k => r.role_id }
}
