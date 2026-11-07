# Control catalog

Each lab control (LC) is the single anchor that framework mappings point to.

## Network

| ID | Control | Implementation | Test | Status |
|---|---|---|---|---|
| LC-01 | Default-deny zones with named allows | `ansible/network/zone_policy.yml`, `playbooks/unifi_firewall.yml` | ATP-004 | Implemented |
| LC-02 | Hypervisor-enforced per-guest allow lists | `tofu/envs/prod/firewall.tf` | ATP-004 | **Partial:** `firewall_enforce` defaults to audit; nodes open |
| LC-03 | One inbound web path through a DMZ | `edge01`, `roles/caddy`, `unifi_public_exposure` | ATP-004, 006 | Implemented |
| LC-04 | Per-site exposure; admin paths internal only | `group_vars/caddy.yml` | ATP-006 | Implemented; source-address based |
| LC-05 | Isolated test networks | `tofu/envs/labnode/{network,kali}.tf`, `roles/lab_node` | ATP-004 | Implemented |
| LC-06 | Split-tunnel VPN with allow-listed devices | `roles/headscale`, `group_vars/headscale.yml` | ATP-007 | Implemented |

## Identity and access

| ID | Control | Implementation | Test | Status |
|---|---|---|---|---|
| LC-07 | Short-lived SSH certificates for people and automation | `roles/step_ca`, `roles/ssh_ca`, `bin/ssh-cert` | ATP-003 | Implemented |
| LC-08 | No standing automation keys | `ssh_ca_enforce` | ATP-003 T8 | **Partial:** currently `false` |
| LC-09 | Host identity by certificate; KRL revocation | `roles/ssh_ca` | ATP-003 | Implemented |
| LC-10 | Central SSO, group-based application access | `tofu/modules/authentik_config` | ATP-006 | Implemented |
| LC-11 | MFA at public sign-in, reputation lockout | `tofu/modules/authentik_config/mfa.tf` | ATP-006 | Implemented; LDAP binds excluded and blocked from outside |
| LC-12 | Device as a sign-in factor | `device_trust.tf`, `bin/device-cert` | ATP-005 | **Partial:** at `enroll` |
| LC-13 | Machine identity: vTPM, EK pins, sealed credentials | `roles/tpm` | ATP-005 | **Partial:** VMs only; no attestation or measured boot |
| LC-14 | Privileged access path | `paw01`, controller allow lists | ATP-004 | **Partial:** a jump box, not a hardware PAW |
| LC-15 | Audited break-glass | `bin/ssh-cert breakglass`, rule 100451 | ATP-003 T6 | Implemented |
| LC-16 | Joiner, mover, leaver procedure | [Access lifecycle](../admin/access-lifecycle.md) | Review | **Partial:** manual; two sources of truth |

## Secrets and cryptography

| ID | Control | Implementation | Test | Status |
|---|---|---|---|---|
| LC-17 | Tiered secrets; least-privilege machine policies | `secrets/policy.yml`, `tofu/modules/openbao_config` | ATP-002 | Implemented; root token still in sops |
| LC-18 | Secret access audit, shipped off-host | OpenBao audit device, Wazuh agent | ATP-002 | Implemented |
| LC-19 | Encrypted, locked IaC state | `backend "pg"`, state encryption | ATP-001 | Implemented |
| LC-20 | Internal PKI with an offline root | `bin/ca-init`, `roles/step_ca`, `roles/x509_cert` | ATP-003 | Implemented; online CA keys in software |
| LC-21 | TLS on platform and admin interfaces | `roles/host_tls`, `roles/admin_ui_tls` | ATP-001 | **Partial:** edge-to-backend hops are HTTP |

## Detection

| ID | Control | Implementation | Test | Status |
|---|---|---|---|---|
| LC-22 | Central log collection | `roles/wazuh_agent`, journald inputs | ATP-008 | Implemented |
| LC-23 | Custom detections with regression tests | `roles/wazuh_manager` | ATP-008 T1 | Implemented |
| LC-24 | File integrity and host audit | Syscheck, `roles/cis_baseline/files/60-cis.rules` | ATP-008 T6 | Implemented on VMs and nodes; LXC cannot load audit rules |
| LC-25 | Vulnerability detection | Wazuh | ATP-008 | Implemented |
| LC-26 | Secrets kept out of logs | `caddy_log_redact_query` | ATP-006 T7 | Implemented |

## Configuration and change

| ID | Control | Implementation | Test | Status |
|---|---|---|---|---|
| LC-27 | Infrastructure as code; review before apply | `ansible/`, `tofu/`, `bin/ap`, `bin/tf` | ATP-012 T4 | Implemented |
| LC-28 | Secure baseline with recorded exceptions | `roles/cis_baseline`, `roles/guest_base` | ATP-012 T1 | Implemented |
| LC-29 | Pre-production environment | `inventories/dev`, `tofu/envs/dev` | Use | Implemented; no firewall parity |
| LC-30 | Patch management with health gates | `roles/patch`, `unattended-upgrades` | ATP-012 | Implemented |
| LC-31 | Pinned versions, checksums, dependency PRs | `# renovate:` pins, `*_sha256`, `renovate.json` | ATP-012 T3 | Implemented; images pinned by tag, not digest |
| LC-32 | Secret and publication scanning | `.pre-commit-config.yaml`, `scripts/check-sanitized.sh` | ATP-012 T5, T6 | Implemented |
| LC-33 | Mobile device management | `fleet/`, `roles/fleet` | ATP-010 | Implemented as a floor; holder can remove it |

## Resilience and response

| ID | Control | Implementation | Test | Status |
|---|---|---|---|---|
| LC-34 | Encrypted, verified guest backups with isolated credentials | `roles/pbs`, `playbooks/backups.yml` | ATP-009 | **Partial:** one copy, same pool as the data |
| LC-35 | Documented, tiered recovery; drills | [DR runbook](../runbooks/disaster-recovery.md) | ATP-009 | **Partial:** drills are scheduled, results not recorded here |
| LC-36 | Off-site source code; mistake recovery by snapshot; incident procedure | `playbooks/forgejo_mirrors.yml`, `roles/zfs_host`, [IR runbook](../runbooks/incident-response.md) | ATP-009 | **Partial:** bulk data has no off-site copy; IR not exercised |
