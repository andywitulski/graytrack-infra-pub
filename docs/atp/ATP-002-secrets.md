# ATP-002: Secrets management

**Objective:** Prove least privilege, audit and tier separation.
**Prerequisites:** OpenBao initialized and cut over.

| ID | Test | Steps | Expected |
|---|---|---|---|
| T1 | Smoke test | `bin/ap prod playbooks/openbao-smoke.yml` | Secrets readable; no AppRole fallback note; sops holds only `sops_only` keys |
| T2 | `ansible` cannot write | With an `ansible` token: `bao kv put kv/services/prod/test a=b` | Permission denied |
| T3 | `tf-authentik` is scoped | With its token, read another service's path | Permission denied |
| T4 | Reads are audited | Run T1, then `ssh ansible@bao01 sudo tail -n5 /var/log/openbao/audit.log \| jq .type` and find the event in Wazuh | Events present, on the host and in the SIEM |
| T5 | Audit device cannot be disabled by API | With the root token: `bao audit disable file/` | Fails or re-appears after restart, because it is declared in config |
| T6 | Tier 0 stays out | `bin/bao-secret prod set openbao_seal_key` | Refused as `sops_only` |

**Evidence:** Output, with values redacted.
