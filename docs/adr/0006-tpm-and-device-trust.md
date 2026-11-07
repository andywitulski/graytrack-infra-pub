# ADR-0006: TPMs for machine identity, registered devices as a sign-in factor

| | |
|---|---|
| **Status** | Accepted, rollout staged |
| **Date** | 2026-10-30, updated 2026-11-04 |
| **Controls** | NIST IA-3, IA-2(1), IA-2(2), AC-19, SC-12, SC-28; SP 800-207 tenets 4 and 5 |

## Context

[ADR-0004](0004-step-ca-for-certificates.md) made credentials short-lived, but two things are still only "something you know":

- **A machine is whoever holds its files.** A copied disk, a restored backup or a clone answers as the original.
- **A person is a password plus a second factor, from anywhere.** Nothing distinguishes a managed workstation from a borrowed laptop, so admin surfaces accept either.

Goal: a registered device replaces the second factor for everyday applications; admin applications need the device **and** a fresh second factor.

Findings that shaped the decision:

- TPM attestation through step-ca needs a TPM attestation CA. The vendor's is commercial. The open-source attempt accepts anything shaped like a TPM.
- Authentik's mutual TLS stage is an Enterprise feature.
- Proxmox vTPM endorsement keys are certified by each node's swtpm local CA, a chain the environment owns.

## Options considered

| Option | Assessment |
|---|---|
| Wait for an open-source attestation CA | Nothing ships; admin surfaces stay device-blind |
| Adopt the WIP attestation project now | Attests nothing |
| Authentik Enterprise for the mTLS stage | A license for one stage; the device-to-user mapping remains unsolved |
| Hardware-bound keys, registered by hash, verified by Caddy, decided by Authentik | Works with what exists; the gap is stated below |

## Decision

- **vTPM on every VM** (not LXCs, which cannot have one).
- **EK inventory and pinning** (`roles/tpm`): a different EK at a host stops the play (rebuild or restore), and the same EK at two hosts stops it (clone).
- **Sealed credentials** with `systemd-creds` for native services. No PCR binding, because these VMs do not measure boot and firmware updates must not lock a service out. Not for Docker stacks, which keep environment on disk anyway.
- **Device certificates:** 30 days, no renewal, key on the device, issued after fresh MFA.
- **Device trust in sign-in:** Caddy verifies the client certificate and forwards only the public key's SHA-256; an Authentik policy matches it against devices registered in OpenTofu. Modes: `off`, `enroll`, `enforce`.

## Consequences

- **Positive:** Removing a device is one line and an apply, even if its certificate is still valid.
- **Negative:** Adding a vTPM restarts the VM. Admin from a phone is refused once enforced.
- **Residual risk (stated plainly):** The CA does not prove the key is in hardware. `bin/device-cert` only ever creates it there and enrollment needs fresh MFA, but a user who exported a software key could register it. An ACME `device-attest-01` provisioner closes this when an open-source attestation CA exists.
- **Dependency:** The header is only as good as the path to Authentik. `enforce` requires `firewall_enforce = true` first.
- **Limitation:** `ca01`'s own keys stay software keys on an LXC.

## Update 2026-11-04: what rollout showed

- **The macOS Secure Enclave is out of reach for now.** It serves only binaries with a Developer ID and provisioning profile, and the plugin's release build is ad-hoc signed. The workstation's device key moves to a YubiKey (PIV), which trusts a token rather than the machine.
- **A device is the machine whose browser signs in.** Caddy asks the browser for the certificate, so `paw01`'s TPM key counts only once `paw01` runs a browser. Until then device trust stays at `enroll`.

## Validation

[ATP-005](../atp/ATP-005-device-trust.md).

## Related

[Roll out device trust](../howto/device-trust.md), [ADR-0007](0007-zone-segmentation-and-guest-firewalls.md)
