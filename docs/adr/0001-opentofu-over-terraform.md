# ADR-0001: Use OpenTofu instead of Terraform

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-09-23 |
| **Controls** | NIST CM-2, CM-3, SC-28 |

## Context

The platform needs declarative provisioning of Proxmox resources. State files contain credentials. The tool
must work offline from a workstation during infrastructure migrations.

## Decision drivers

- State and plans must be encrypted at rest without a hosted service.
- Open-source license, with no hosted dependency.
- Skills and code must transfer to common enterprise tooling.

## Options considered

| Option | Assessment |
|---|---|
| Terraform (BSL) | Largest market share; no built-in client-side state encryption |
| OpenTofu (MPL) | Same HCL and provider ecosystem; native state and plan encryption |

## Decision

Use **OpenTofu**, pinned in `mise.toml`, with state and plan encryption enforced.

## Consequences

- **Positive:** HCL, workflow and providers transfer directly to Terraform environments.
- **Negative:** Terraform-only features such as HCP Terraform are unavailable.
- **Residual risk:** The encryption passphrase becomes a critical secret. It is stored in sops as tier 0.

## Validation

[ATP-001](../atp/ATP-001-platform-tier.md): state in the backend is ciphertext.

## Related

[ADR-0002](0002-tofu-state-in-postgresql.md)
