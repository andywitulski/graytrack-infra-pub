# ADR-0012: Fleet for Apple device management

| | |
|---|---|
| **Status** | Accepted |
| **Date** | Recorded retroactively 2026-11-05 |
| **Controls** | NIST CM-2, CM-6, CM-8, AC-19, IA-3; CIS Controls 1, 4 |

## Context

Mobile devices hold VPN access and application sessions. A passcode floor, an always-on VPN and an inventory
should come from policy, not memory.

## Decision drivers

- Self-hosted and open source.
- Configuration as code.
- SSO for the console.
- Personal devices stay personal: no supervision, no erase.

## Options considered

| Option | Assessment |
|---|---|
| No MDM | Nothing enforced, nothing inventoried |
| MicroMDM or NanoMDM | Minimal, with a lot left to build |
| Fleet (free tier) | GitOps, SSO, inventory, profiles; no remote wipe or VPP |
| Commercial MDM | Per-device cost |

## Decision

**Fleet on `mdm01`** with profile-based enrollment. `fleet/` holds settings and profiles, applied with
`bin/fleet-gitops`. Only MDM device paths are public (`public_path_regexp`). The console signs in through Authentik
SAML, with a local break-glass admin in the password manager.

## Consequences

- **Positive:** Drift is corrected on the next run. Enrolled devices get the root CA and VPN automatically.
- **Negative:** The free tier has no remote lock or wipe; Find My covers lost devices. The GitOps user is a full admin, because the narrower role is Premium.
- **Residual risks:** A device's holder can remove the profile, which removes what it installed. This is a floor, not a lock. The push certificate must renew yearly from the same Apple Account, or every device re-enrolls.
- **Privacy:** Fleet sees model, serial, OS and managed items, not personal content. A device is enrolled only with its owner's agreement.
- **Next:** Managed Device Attestation through step-ca, so a trusted device is proven rather than listed.

## Validation

[ATP-010](../atp/ATP-010-endpoint-management.md).

## Related

[Set up device management](../howto/mdm.md)
