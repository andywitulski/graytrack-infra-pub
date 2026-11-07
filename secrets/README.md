# secrets: encrypted tier 0 material

Only `policy.yml` is published (key names, no values). The encrypted files are excluded, and `.gitignore`
blocks them, because publishing ciphertext makes the secrets' safety depend forever on one age key.

Create these in your private fork (`docs/howto/platform-tier.md`):

| File | Created by | Holds |
|---|---|---|
| `<env>.enc.env` | you, with `sops` | `PROXMOX_VE_ENDPOINT`, `PROXMOX_VE_API_TOKEN`, `TF_VAR_state_passphrase` |
| `openbao-<env>.enc.yaml` | `bin/bao-init`, `bin/bao-approle` | root token, recovery keys, AppRole secret IDs |
| `ca-<env>.enc.yaml` | `bin/ca-init` | intermediate and SSH CA keys, provisioner keys |
| `ca-<env>-root.enc.yaml` | `bin/ca-init` | root CA key; no playbook reads it |
| `authentik-<env>.enc.yaml` | you | Authentik API URL and token for OpenTofu |
| `ansible/inventories/<env>/group_vars/all/secrets.sops.yml` | `bin/gen-service-secrets` | Ansible secrets marked `sops_only` |

Before you commit in a private fork, put your age public key in `.sops.yaml`.
