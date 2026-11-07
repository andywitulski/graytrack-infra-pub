# Gap register

Open gaps, from this assessment and the ADRs. Risk is a judgment for this environment: likelihood and impact in a small private deployment.

| ID | Gap | Risk | Controls | Plan |
|---|---|---|---|---|
| G-01 | **No off-site backup of guests or bulk data.** The datastore shares a pool with the data, and `tank` datasets have snapshots only | High | CP-6, CP-9, CIS 11 | Off-site NAS: PBS sync and ZFS replication |
| G-02 | **Guest firewalls in audit mode by default;** node input policy open | High | SC-7, AC-4 | Enforce once rule 100421 is quiet; plan node filtering separately |
| G-03 | **No outbound alert channel.** No e-mail or webhook integration is configured, so a critical alert waits for a dashboard review | High | IR-4, IR-6, SI-4(5) | Add a Wazuh integration for level 10+ through a channel independent of the lab |
| G-04 | **No encryption at rest on node storage.** No LUKS or ZFS native encryption is configured. PBS backups are encrypted; live disks are not | Medium | SC-28, MP-5 | ZFS native encryption for sensitive datasets on a new pool; physical security meanwhile |
| G-05 | **Containers lack hardening options.** None of the compose stacks set `cap_drop`, `no-new-privileges`, `read_only`, a non-root `user`, or memory limits | Medium | CM-7, SC-39, OWASP D01, D04, D05, D07 | Add per stack, testing in dev |
| G-06 | **No security headers at the edge.** Caddy sets no global HSTS, CSP or frame policy; applications rely on their own | Medium | SC-8, OWASP A02 | Caddy snippet with HSTS and `nosniff`; CSP per application |
| G-07 | **Static automation keys remain** (`ssh_ca_enforce: false`) | Medium | IA-5, AC-2 | Complete the phase 2 checklist |
| G-08 | **Device trust not enforced;** admin surfaces accept any device with MFA | Medium | IA-3, AC-19 | Hardware-backed device key or desktop PAW, then `enforce`; depends on G-02 |
| G-09 | **Plain HTTP between edge and backends** inside the Services zone | Medium | SC-8 | Backend certificates from `ca01` |
| G-10 | **OpenBao root token still in use** by `bin/tf-bao` | Medium | AC-6(5), IA-2 | OIDC for admins, then revoke |
| G-11 | **Static seal key beside the data it unlocks** | Low to medium | SC-12 | Accepted ([ADR-0003](../adr/0003-openbao-for-secrets.md)); HSM if ever available |
| G-12 | **CA keys in software on an LXC** | Medium | SC-12, SC-17 | TPM-backed VM; hardware-backed root |
| G-13 | **Hardware key attestation missing:** the CA cannot prove a device key is in hardware | Low | IA-3 | ACME device attestation when available |
| G-14 | **No automated network-level blocking.** No active response or ban tool; only Authentik's reputation policy | Low to medium | SI-4(7), SC-7 | Consider Wazuh active response or a Caddy rate limit on `auth` |
| G-15 | **No web application firewall or independent penetration test** | Low | CA-8, CIS 18 | Periodic self-test from `kali01`; external scan |
| G-16 | **Trust by source address.** A compromised internal host passes `lan_paths` | Medium | AC-3, SP 800-207 | Move admin paths behind identity as well |
| G-17 | **Access provisioning is manual,** with lists in code as well as IdP groups | Low | AC-2(1) | Generate from Authentik groups |
| G-18 | **Single points of failure:** no HA for `edge01`, `idp01`, `pg01`, or `pve03` | Accepted for scale | CP-2, SC-5 | Documented recovery |
| G-19 | **Images pinned by tag, not digest** | Low | SR-4, SR-11, OWASP A03 | Add digests through Renovate |
| G-20 | **IR and DR not exercised end to end,** and no recorded RTO results in this repository | Medium | IR-3, CP-4 | Tabletop exercise; run the drills and retain evidence |
