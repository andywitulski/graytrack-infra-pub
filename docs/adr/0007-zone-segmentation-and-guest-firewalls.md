# ADR-0007: Zone policy plus hypervisor-enforced guest firewalls

| | |
|---|---|
| **Status** | Accepted; guest firewall enforcement staged |
| **Date** | Recorded retroactively 2026-11-05; rollout began October 2026 |
| **Controls** | NIST SC-7, SC-7(5), AC-4, CM-7, AU-12; SP 800-207 tenet 2; NSA/CISA misconfiguration 4 |

## Context

VLANs and a gateway policy control traffic between zones, but traffic inside one VLAN never reaches the
gateway. A compromised application could reach its neighbors freely. Firewalls inside guests share a fate with
the guest, and Docker rewrites iptables on its own.

## Decision drivers

- Lateral movement must be limited within a zone.
- A compromised guest must not be able to remove its own filter.
- The rules must be code, with one source for each address.
- Rollout must not cause an outage from an unknown dependency.

## Options considered

| Option | Assessment |
|---|---|
| Gateway zone policy only | Blind to same-VLAN traffic |
| In-guest firewalls (nftables, ufw) | Root in the guest disables them; Docker interferes |
| One VLAN per service | Heavy; many gateway rules |
| Zone policy plus Proxmox guest firewall | Enforced on the node in front of the NIC, including same-VLAN traffic |

## Decision

Two layers. **Zone policy** (`ansible/network/zone_policy.yml`) is default-block between zones, with named
allows. **Guest firewall** (`tofu/envs/prod/firewall.tf`) is an inbound allow list per guest. Outbound stays with
the zone policy. OpenTofu reads addresses from the zone policy file, so nothing is typed twice.

Rollout is **audit, then enforce:** with `firewall_enforce = false`, unmatched traffic is accepted and logged
(Wazuh rule 100421). When that stays quiet through normal use, enforcement turns on; drops become rule 100422,
with 100423 for bursts.

## Consequences

- **Positive:** Enforcement is outside the guest's trust boundary. Audit mode reveals real dependencies.
- **Negative:** Every new service needs entries in both layers. CIS scans inside a guest cannot see the firewall and report it as absent ([exceptions](../compliance/cis-debian13-exceptions.md)).
- **Residual risk:** Until enforcement is on, guests accept unmatched inbound traffic, so same-zone lateral movement is detected but not blocked. Node input policy is also still open, because a mistake there locks out the management UI and cluster traffic.

## Validation

[ATP-004](../atp/ATP-004-segmentation.md).

## Related

[Roll out host firewalls](../howto/host-firewall.md), [Network and trust zones](../architecture/network-and-trust-zones.md)
