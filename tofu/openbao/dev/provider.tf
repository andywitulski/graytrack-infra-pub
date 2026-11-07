# Address, CA file and token come from VAULT_ADDR, VAULT_CACERT and VAULT_TOKEN (bin/tf-bao).
provider "vault" {
  # OpenBao forked from Vault 1.14 and reports its own 2.x version, which the provider would read as a
  # Vault release newer than any it knows, and then use API features OpenBao does not have. Pin the API
  # level instead of asking the server.
  skip_get_vault_version = true
  vault_version_override = "1.14.0"
}
