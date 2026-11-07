# ADR-0004: step-ca for X.509 and SSH certificates

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-10-28 |
| **Controls** | NIST IA-2, IA-5, IA-9, AC-2, AU-10, SC-12, SC-17 |

## Context

Every SSH login used a long-lived key. Rebuilding a host changed its host key. Nobody could say which key had
logged in where, and removing a person meant finding every `authorized_keys` file they were in. Internal TLS
services each had a small self-signed CA that only their own clients trusted.

## Decision drivers

- Short-lived credentials bound to an identity, a person or an automation account.
- Host identity that survives rebuilds.
- Revocation that takes effect, and logins attributable in the SIEM.
- CA failure must not stop the automation needed to fix it.

## Options considered

| Option | Assessment |
|---|---|
| Static keys, better managed | Still long-lived and copied; no attribution |
| OpenBao SSH and PKI engines | Works, but the user flow is manual, there is no ACME, and CA and secrets share one blast radius |
| step-ca (Apache-2.0) | Built for this: OIDC login into ssh-agent, JWK provisioners, templates, policy, ACME, PostgreSQL storage |
| Teleport, Boundary | Much more to run; they replace sshd's own checks |

## Decision

Run **step-ca on `ca01`**, configured from the repository with remote management off.

- **Root CA:** created on the controller by `bin/ca-init`, never deployed. No playbook reads its sops file.
- **Intermediate, SSH user CA, SSH host CA:** on `ca01`, encrypted under their own password.
- **`step-ca` (:443):** JWK provisioners `ansible`, `tofu` (8 h, fixed principal) and `hosts` (90 days, inventory names only).
- **`step-ca-login` (:8443):** Authentik OIDC for people (16 h, principal = username).

Hosts trust certificates through sshd's `TrustedUserCAKeys`, per-account principal files and a KRL. Host keys
are signed from the controller, so no guest needs a network path to `ca01`.

The instances are split because step-ca will not start without its OIDC discovery document. An IdP outage must
not stop the certificates automation needs to repair the IdP.

## Consequences

- **Positive:** The same sshd mechanisms are used by enterprise SSH CAs. A rebuilt host stays trusted through one `@cert-authority` line. Every login carries a key ID into the SIEM.
- **Negative:** `ca01` is critical for routine work; host certificates must be renewed (see [Admin UI TLS](../howto/admin-ui-tls.md)).
- **Residual risk:** The SSH user CA key can sign for any principal; it is treated as tier 0 alongside the age key.
- **Break-glass:** `bin/ssh-cert <env> breakglass` signs offline and raises Wazuh rule 100451.
- **Staged:** `ssh_ca_enforce` removes static automation keys once proven. It is currently off.

## Validation

[ATP-003](../atp/ATP-003-certificates-and-ssh.md).

## Related

[Build the CA](../howto/certificate-authority.md), [Use certificates](../howto/using-certificates.md), [Rotation and compromise](../runbooks/certificate-rotation-and-compromise.md)
