# ADR-0003: OpenBao as the secrets manager, sops/age as tier 0

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-10-28 |
| **Controls** | NIST IA-5, AC-6, AU-2, AU-12, SC-12, SC-28 |

## Context

Every secret sat in sops files encrypted to one age key. That works for building from a workstation, but
whoever can decrypt the file reads every secret. There is no audit trail, no expiring credentials, and no API for
services to fetch or rotate secrets.

## Decision drivers

- Per-consumer access control and an audit trail of reads.
- Short-lived tokens for machine identities.
- Open-source license, consistent with [ADR-0001](0001-opentofu-over-terraform.md).
- API and skills that transfer to Vault environments.

## Options considered

| Option | Assessment |
|---|---|
| sops only | Simplest; none of the required properties |
| HashiCorp Vault | Reference product; BSL license since 2023 |
| OpenBao (MPL-2.0) | Linux Foundation fork with the same API and provider; PostgreSQL HA storage, declarative audit devices, static-key auto-unseal |
| Infisical, Bitwarden Secrets Manager | Less common in enterprise IAM and platform roles |

## Decision

Run **OpenBao on `bao01`**, configured as code in `tofu/openbao/<env>`. Secrets are tiered:

- **Tier 0, sops/age:** what builds or unlocks the platform. Proxmox API token, state passphrase, PostgreSQL passwords, the seal key, recovery keys, root token.
- **Tier 1, OpenBao:** service and automation secrets, read by machine identities under least-privilege policies with every access in the audit log, which the Wazuh agent ships off-host.

Storage is PostgreSQL on `pg01`. Unseal uses a static seal from sops, so a reboot needs no human. The audit
device is declared in the config file, so no API token can disable it.

## Consequences

- **Positive:** Each secret has one source. Migration was a copy and proof, not a cutover (`bin/bao-import-sops`, `playbooks/openbao-smoke.yml`).
- **Negative:** Every `bin/ap` run depends on OpenBao. A documented bypass exists for recovery (`LABSTACK_OPENBAO=off`).
- **Residual risk:** The static seal key on `bao01` plus a copy of its database together decrypt everything. PBS backups are encrypted and the key file is `root:openbao 0640`. An HSM or cloud KMS would separate them; this is accepted and documented.
- **Open:** `bin/tf-bao` uses the root token from sops until an admin auth method exists. Next step: OIDC login through Authentik, then revoke the root token.
- **Enables:** Dynamic database credentials; PKI for internal services.

## Validation

[ATP-002](../atp/ATP-002-secrets.md).

## Related

[ADR-0002](0002-tofu-state-in-postgresql.md), [Manage secrets in OpenBao](../howto/secrets-openbao.md)
