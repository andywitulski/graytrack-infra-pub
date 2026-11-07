# Top 10 list mappings

Most of the applications here are third-party. The tables below cover what **the platform** does about each risk, and note where responsibility stays with the application vendor. Patching and pinned versions (LC-30, LC-31) apply throughout.

## OWASP Top 10:2025

| ID | Risk | Platform mitigation | LC | Status |
|---|---|---|---|---|
| A01 | Broken Access Control | Per-application groups, internal-only admin paths, default-deny exposure, reverse proxy strips identity headers. Source-address trust remains | LC-04, LC-10 | Partial (G-16) |
| A02 | Security Misconfiguration | Everything in code; CIS baseline; drift checks; default sites are internal only. No edge security headers | LC-27, LC-28 | Partial (G-05, G-06) |
| A03 | Software Supply Chain Failures | Exact pins, checksums, Renovate PRs, `gitleaks`; tags rather than digests. Third-party Jellyfin plugin and Caddy DNS module noted | LC-31, LC-32 | Partial (G-19) |
| A04 | Cryptographic Failures | Public and internal PKI, TLS 1.3 to the database, encrypted state and backups, no hand-held secrets. Internal HTTP and unencrypted disks | LC-17, LC-19, LC-20 | Partial (G-04, G-09) |
| A05 | Injection | Vendor responsibility; vars plugin marks secrets unsafe, so they are never templated; no WAF | | Partial (G-15) |
| A06 | Insecure Design | ADRs with threat reasoning; separate step-ca instances; first-run claim before exposure; tier 0 separation | LC-17, LC-27 | Implemented |
| A07 | Authentication Failures | MFA, reputation lockout, no password prompt on the internet for Jellyfin, app passwords per device | LC-11 | Implemented |
| A08 | Software or Data Integrity Failures | Checksummed downloads, signed ISO verification, signed host and user certificates, EK pins, FIM | LC-09, LC-13, LC-24, LC-31 | Implemented |
| A09 | Security Logging and Alerting Failures | Central logs, tested rules, tamper alerts, token redaction. **Alerts are not pushed** | LC-22, LC-23, LC-26 | Partial (G-03) |
| A10 | Mishandling of Exceptional Conditions | Health gates stop patch runs; `sshd -t` before reload; rule files restored on failed test; run stops if OpenBao is unreadable; read-back of port forward | LC-23, LC-30 | Implemented |

SSRF, a separate item in the 2021 edition, is reduced here by default-deny egress in the zone policy.

## OWASP API Security Top 10 (2023)

APIs in scope: Authentik, Forgejo, Fleet, OpenBao, Proxmox, Nextcloud. Object-level logic is the vendor's.

| ID | Risk | Platform mitigation | Status |
|---|---|---|---|
| API1 | Broken Object Level Authorization | Vendor; authenticated access only | Vendor |
| API2 | Broken Authentication | OIDC, certificates, narrow tokens, short TTLs | Implemented |
| API3 | Broken Object Property Level Authorization | Vendor | Vendor |
| API4 | Unrestricted Resource Consumption | Authentik reputation; no general rate limits or container memory limits | Partial (G-05, G-14) |
| API5 | Broken Function Level Authorization | Admin APIs blocked from outside (`/api/v3/admin/*`, `/api/v1/admin/*`, Fleet console API) | Implemented |
| API6 | Unrestricted Access to Sensitive Business Flows | Sign-up disabled or internal only | Implemented |
| API7 | Server Side Request Forgery | Default-deny egress; `edge01` has no path to management | Partial |
| API8 | Security Misconfiguration | Code-defined; TLS; no remote management on step-ca | Implemented |
| API9 | Improper Inventory Management | Caddy sites are the published list; dev is unreachable from outside | Implemented |
| API10 | Unsafe Consumption of APIs | Pinned CAs; verify-full; TLS verification against pins | Implemented |

## OWASP Docker Top 10

| ID | Risk | Current state | Status |
|---|---|---|---|
| D01 | Secure User Mapping | No `user:` set by the stacks; vendor image defaults | Gap (G-05) |
| D02 | Patch Management Strategy | Pinned tags, Renovate, host patching | Implemented |
| D03 | Network Segmentation and Firewalling | Guest firewall outside Docker's reach; one stack per VM | Partial (G-02) |
| D04 | Secure Defaults and Hardening | Host hardened; no `cap_drop` or `no-new-privileges` | Gap (G-05) |
| D05 | Maintain Security Contexts | Separate VMs per service; no Docker socket mounted in compose stacks | Partial |
| D06 | Protect Secrets | From OpenBao, not in images. Environment files on disk, which is why sealing is not used for Docker | Partial |
| D07 | Resource Protection | No memory or CPU limits in compose; VM limits apply | Partial (G-05) |
| D08 | Container Image Integrity and Origin | Exact tags from vendor registries; no digests or signature checks | Partial (G-19) |
| D09 | Follow Immutable Paradigm | Rebuilt from code; no `read_only` root | Partial (G-05) |
| D10 | Logging | stdout to journald, then Wazuh for Caddy and Authentik | Implemented |

## OWASP Non-Human Identities Top 10 (2025)

| ID | Risk | Platform mitigation | Status |
|---|---|---|---|
| NHI1 | Improper Offboarding | Removing an identity is a code change; provisioners rotate | Implemented |
| NHI2 | Secret Leakage | `gitleaks`, sops, hidden prompts, values never printed | Implemented |
| NHI3 | Vulnerable Third-Party NHI | Fine-grained GitHub token, scoped to the backup org | Implemented |
| NHI4 | Insecure Authentication | Certificates and short-lived tokens; AppRole bound to address | Implemented |
| NHI5 | Overprivileged NHI | Narrow OpenBao policies. Fleet GitOps user is a full admin (free tier); root token in use | Partial (G-10) |
| NHI6 | Insecure Cloud Deployment Configurations | Minimal cloud use; token in sops; stage 2 not built | Implemented |
| NHI7 | Long-Lived Secrets | 8 h automation certificates; 90-day secret IDs. Static keys remain; some API tokens last a year | Partial (G-07) |
| NHI8 | Environment Isolation | Separate identities per environment; `labnode` backup token isolated | Implemented |
| NHI9 | NHI Reuse | One identity per tool (`ansible`, `tofu`, `tf-authentik`) | Implemented |
| NHI10 | Human Use of NHI | People have their own principals; break-glass is alerted. `ansible` can still be used by an admin | Partial |

## OWASP Top 10 for LLM Applications (2025)

Scope is limited to `gpu01` (self-hosted Ollama and a pgvector database) and `ai01`. Application-layer risks belong to whatever application is built on them.

| ID | Risk | Platform position | Status |
|---|---|---|---|
| LLM01 | Prompt Injection | Application layer | N/A here |
| LLM02 | Sensitive Information Disclosure | Local inference; data stays on site; access limited to controllers and named hosts | Implemented |
| LLM03 | Supply Chain | Ollama pinned; model list in code. Model files are not checksum-verified | Partial |
| LLM04 | Data and Model Poisoning | Models pulled by name; embeddings can be rebuilt | Partial |
| LLM05 | Improper Output Handling | Application layer | N/A here |
| LLM06 | Excessive Agency | No agent has platform credentials | Implemented |
| LLM07 | System Prompt Leakage | Application layer | N/A here |
| LLM08 | Vector and Embedding Weaknesses | Database over TLS verify-full, one role, firewall allow list | Implemented |
| LLM09 | Misinformation | Application layer | N/A here |
| LLM10 | Unbounded Consumption | Network-restricted; no quotas | Partial |

## NSA/CISA Top Ten Cybersecurity Misconfigurations (AA23-278A)

| # | Misconfiguration | Platform position | LC | Status |
|---|---|---|---|---|
| 1 | Default configurations of software and applications | Generated secrets, sign-up off, claim before exposure, self-signed certificates replaced | LC-20, LC-28 | Implemented |
| 2 | Improper separation of user and administrator privilege | Controllers, `sudo` set per person, separate automation identities | LC-07, LC-14 | Partial |
| 3 | Insufficient internal network monitoring | Gateway, firewall audit, host agents, tuned rules | LC-22, LC-23 | Implemented |
| 4 | Lack of network segmentation | Six zones, DMZ, isolated networks, guest firewalls | LC-01, LC-02, LC-05 | Partial (G-02) |
| 5 | Poor patch management | Daily security updates, weekly runs, pins, health gates | LC-30, LC-31 | Implemented |
| 6 | Bypass of system access controls | Header stripping, regex path controls tested for bypass, enforcement on the hypervisor. `idp01` is reachable around Caddy until enforce | LC-02, LC-04 | Partial (G-02) |
| 7 | Weak or misconfigured MFA methods | TOTP and WebAuthn; LDAP without MFA blocked from outside. TOTP is not phishing-resistant | LC-11, LC-12 | Partial (G-08) |
| 8 | Insufficient ACLs on network shares and services | Per-user shares, SMB3, LAN only, internal `pg_hba` per host. SMB encryption is "desired", not required | LC-01, LC-04 | Implemented |
| 9 | Poor credential hygiene | Short-lived certificates, tiered secrets, no password on guests, secret scanning. Static keys remain | LC-07, LC-08, LC-17, LC-32 | Partial (G-07) |
| 10 | Unrestricted code execution | Checksums and pinned software. No application allow-listing or noexec on `/dev/shm` | LC-31 | Partial |
