# ADR-0009: Split-tunnel overlay VPN with Headscale

| | |
|---|---|
| **Status** | Accepted |
| **Date** | Recorded retroactively 2026-11-05 |
| **Controls** | NIST AC-17, AC-17(2), AC-19, SC-8; SP 800-207 tenets 2 and 5 |

## Context

Private services need to be reachable away from the site, and the long-term goal is to expose only what cannot
run a VPN client. A traditional full-tunnel VPN adds latency for all traffic and is often turned off by users.

## Decision drivers

- No dependence on a hosted control plane.
- SSO with MFA to join.
- A joined device must not automatically reach the network.
- Clients must work behind restrictive NAT.

## Options considered

| Option | Assessment |
|---|---|
| Plain WireGuard | Manual key distribution; no SSO |
| Hosted Tailscale | Excellent client, but a third-party control plane |
| Headscale with official Tailscale clients | Self-hosted control plane; polished clients; OIDC |
| OpenVPN or IPsec | Heavier, weaker mobile experience |

## Decision

- **`hs01`** runs Headscale. **`ts01`** is a subnet router advertising only `/32` routes: `edge01`, the DNS server and `mail01`.
- **Split DNS** sends only the lab's names through the tunnel.
- **Device trust is a reviewed commit.** Signing in only puts a device on the tailnet. It reaches the lab once its overlay address is listed in `headscale_trusted_devices`. There is no device-to-device traffic. Overlay addresses are bound to WireGuard keys, so they cannot be spoofed.
- **`ts02`** is an optional exit node, granted per device, for untrusted networks.
- Device keys expire after 180 days.

## Consequences

- **Positive:** A stolen credential alone gets an attacker a tailnet presence but no route. Admin surfaces are not in the tunnel.
- **Negative:** Three places must agree to add a destination: routes, ACLs and zone policy.
- **Residual risks:** Trust covers the device that was checked, not its current state; a stolen, unlocked device stays trusted until removed. `hs` must stay public. Relays are third-party, though traffic is end-to-end encrypted.

## Validation

[ATP-007](../atp/ATP-007-remote-access.md).

## Related

[Set up remote access](../howto/vpn.md), [ADR-0012](0012-fleet-for-mobile-device-management.md)
