# ATP-001: Platform tier

**Objective:** Prove state is durable, locked and encrypted, and that the platform's dependencies behave as designed.
**Prerequisites:** [Platform tier built](../howto/platform-tier.md). Run from a controller.

| ID | Test | Steps | Expected |
|---|---|---|---|
| T1 | State reachable over verified TLS | `source bin/lib/platform.sh && platform_env prod "$PWD"`, then `psql "$PG_CONN_STR" -c '\dn'` | Lists schemas `envs`, `authentik`, `platform`, `openbao` |
| T2 | Wrong CA refused | Connect with `sslmode=verify-full` and a different `sslrootcert` | Connection fails on certificate verification |
| T3 | State is ciphertext | Query `states` in the `tofu_state` database; inspect the data | Encrypted payload; no readable resource attributes or secrets |
| T4 | Access restricted to controllers | From a non-controller host: `psql` to `pg01:5432` | Refused or timed out; `pg_hba` rejects |
| T5 | Concurrent runs locked | Start `bin/tf prod plan -lock-timeout=0` in two terminals | The second fails with a lock error |

**Evidence:** Command output for each test.
