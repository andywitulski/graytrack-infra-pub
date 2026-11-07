# ATP-007: Remote access

**Objective:** Prove joining is not access, and only intended traffic enters.
**Prerequisites:** [VPN deployed](../howto/vpn.md). Test from a client away from the site.

| ID | Test | Steps | Expected |
|---|---|---|---|
| T1 | Join requires SSO and group | Sign in with a user outside `headscale-users` | Denied |
| T2 | Untrusted device reaches nothing | Join a new device; do not trust it; `curl https://sync.example.com` | Fails. Listed under "Rejected devices" |
| T3 | Trusted device works | Trust it; run the play; repeat T2 | Internal-only site answers (302 to Authentik) |
| T4 | Only listed routes | From a trusted device: `nc -vz __MGMT_NET__.2 8006`, and to another tailnet device | Blocked |
| T5 | Split DNS and tunnel | `dig +short auth.example.com`; `dig +short hs.example.com`; check a what-is-my-IP site | Internal address; public address; device's own public IP |
| T6 | Revocation | Expire the test device, remove its line, run the play | Access stops immediately |

**Evidence:** Output, with overlay addresses redacted.
