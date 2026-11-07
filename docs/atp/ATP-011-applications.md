# ATP-011: Applications

**Objective:** Prove application-specific access decisions.

| ID | Application | Test | Expected |
|---|---|---|---|
| T1 | Vaultwarden | From outside: `/admin`; a new sign-up | 403; refused |
| T2 | Vaultwarden | Inspect server data for a vault item | Ciphertext only |
| T3 | Forgejo | From outside: `/user/sign_up`, `/-/admin`; SSH to port 2222 | 403; 403; no route |
| T4 | Audiobookshelf | `POST /init` from outside | Rejected: already claimed |
| T5 | Mail | From outside: connect to 993. From inside: send from the internal address to an external one. Send as another person's address | No route; "Relay not allowed"; refused |
| T6 | Nextcloud Office | From outside: Collabora admin console | 403 |
