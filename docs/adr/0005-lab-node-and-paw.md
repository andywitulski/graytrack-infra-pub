# ADR-0005: Standalone lab node with an admin workstation VM

| | |
|---|---|
| **Status** | Accepted. Revised 2026-10-29: `paw01` on Management, `gpu01` on Services, uses prod's platform tier |
| **Date** | 2026-10-10 |
| **Controls** | NIST AC-6(5), SC-7, CM-4, SA-3 |

## Context

A single workstation running a desktop OS held five jobs at once: desktop session, Ansible and OpenTofu
controller, libvirt host for the nested dev cluster, GPU host, and jump host into the security VLAN. The jobs
interfered with each other, and the dev cluster was hand-shaped outside the OpenTofu workflow.

## Decision drivers

- Separate administrative functions from general use.
- Build the dev cluster with the same tooling as production.
- Do not weaken cluster quorum.

## Options considered

| Option | Assessment |
|---|---|
| Keep the desktop OS and tune it | Least work; keeps five roles on one OS |
| Join the prod cluster as a fourth node | One API, but an even voter count and an unreliable quorum member |
| Standalone Proxmox node, its own root and inventory | Jobs become VMs: `paw01`, `gpu01`, `pvedev1`-`3` |

## Decision

Build a **standalone Proxmox node, `labnode`**, as its own environment.

- The node and `paw01` sit on Management, so existing admin policies and ipsets cover them. `gpu01` sits on Services.
- `paw01` is a second controller. Admin credentials are restored by hand, never by automation.
- `labnode` has no platform tier of its own: state is in prod's `pg01` (schema `labnode`), and prod's `ca01` signs its host certificates.
- The node's management stays local (PAM plus TOTP, no SSO), so an IdP compromise does not reach the box that administers it.
- Dev networking uses Proxmox SDN.

## Consequences

- **Positive:** The dev cluster is ordinary OpenTofu resources. Admin work moves off a general-purpose desktop.
- **Negative:** One more environment to keep in step.
- **Residual risk:** `paw01` is a jump box, not a hardware PAW: root on the node owns it. That admin path is therefore the most sensitive and gets the strictest access.
- **Dev isolation:** The dev cluster is reachable only from `paw01`.

## Validation

[ATP-004](../atp/ATP-004-segmentation.md) (isolation of `kali01`).

## Related

[Build the lab node](../howto/lab-node.md), [Dev environment](../howto/dev-environment.md)
