# Manage secrets in OpenBao

**Goal:** Store, change and audit service secrets, and migrate an environment from sops to OpenBao.

**Why:** [ADR-0003](../adr/0003-openbao-for-secrets.md). **Accept with:** [ATP-002](../atp/ATP-002-secrets.md).

| What | Where | Written by | Read by |
|---|---|---|---|
| Service secrets | `kv/services/<env>/<service>` | `bin/gen-service-secrets`, `bin/bao-secret` | Each `bin/ap` run |
| OIDC client secrets, LDAP bind password | `kv/services/prod/tf-authentik` | `bin/tf-ak prod apply` | Same |
| Tier 0 and break-glass (`sops_only`) | `inventories/<env>/group_vars/all/secrets.sops.yml` | `bin/gen-service-secrets`, `sops set` | `bin/ap` |
| OpenBao's own credentials | `secrets/openbao-prod.enc.yaml` | `bin/bao-init`, `bin/bao-approle` | `bin/bao-*`, `bin/ap`, `bin/tf-ak` |

`<service>` is the variable name up to its first underscore: `forgejo_db_pass` lives in `kv/services/prod/forgejo`. `labnode` uses prod's OpenBao. `dev` has none and stays on sops.

`sops_only` in `secrets/policy.yml` covers what builds or unseals the platform (`openbao_*`, `tofu_state_*`, `stepca_*`), plus what must work with `bao01` down: `pbs_encryption_key` and `unifi_*`.

## How a run gets secrets

`bin/ap` logs in as `ansible` (X.509 from `ca01` if `PLATFORM_BAO_AUTH=cert`, otherwise AppRole). The vars plugin `ansible/plugins/vars/labstack_openbao.py` reads everything under `kv/services/<env>/`, revokes its token, and hands the fields to the play as variables. There is one login per run. Values are marked unsafe, so they are never templated. A key stored under two services stops the run.

If OpenBao cannot be read, the run stops before any task.

## Everyday tasks

| Task | Command |
|---|---|
| List keys (names only) | `bin/bao-secret prod list` |
| Check a key without showing it | `bin/bao-secret prod check caddy_dns_api_token` |
| Set with a hidden prompt | `bin/bao-secret prod set caddy_dns_api_token` |
| Generate missing secrets | `bin/gen-service-secrets prod` |
| Copy to the clipboard, not the screen | `bin/bao-secret prod copy <key>` |

`bin/bao-secret` refuses `sops_only` and `tofu_owned` keys. Writes are check-and-set, and OpenBao keeps 10 versions. Undo with `bao kv rollback -version=N`.

**Add a new OIDC application:** add its client secret to `openbao.tf` in `tofu/authentik/prod` and to `tofu_owned` in `secrets/policy.yml`.

## Migrate an environment (once)

Order: prod, then `labnode`. Services do not change: same values, new source.

1. Create the `tf-authentik` identity.
   ```bash
   bin/tf-bao prod plan && bin/tf-bao prod apply
   ```
   ```bash
   bin/bao-approle prod tf-authentik
   ```
2. Have Authentik's root write its secrets. The plan should add `vault_kv_secret_v2.authentik` and nothing else.
   ```bash
   bin/tf-ak prod init && bin/tf-ak prod plan && bin/tf-ak prod apply
   ```
3. Prefer certificate login: AppRole secret IDs expire at 90 days. Set `PLATFORM_BAO_AUTH=cert` in `client.env`. AppRole stays as a fallback.
4. Copy, prove, cut over.
   ```bash
   bin/bao-import-sops prod --dry-run
   ```
   ```bash
   bin/bao-import-sops prod
   ```
   ```bash
   bin/ap prod playbooks/openbao-smoke.yml
   ```
   ```bash
   bin/ap prod playbooks/services.yml --check --diff
   ```
   ```bash
   bin/bao-import-sops prod --cutover
   ```
   ```bash
   bin/ap prod playbooks/openbao-smoke.yml
   ```
   The check run must report no changes. Confirm with `sops filestatus` and commit.
5. Repeat step 4 for `labnode`, then `git pull` on `paw01`, since its weekly certificate run now reads OpenBao too.

## Roll back

The values remain in git history, encrypted.

```bash
git revert <cutover-commit>
```
```bash
LABSTACK_OPENBAO=off bin/ap prod playbooks/services.yml --check --diff
```

Keep `LABSTACK_OPENBAO=off` exported until OpenBao is fixed. A secret changed in OpenBao meanwhile must be copied back by hand.

## With `bao01` down

Only playbooks that need `sops_only` keys work:

```bash
LABSTACK_OPENBAO=off bin/ap prod playbooks/platform.yml --limit bao01
```
```bash
LABSTACK_OPENBAO=off bin/ap prod playbooks/unifi_firewall.yml
```

## Design notes

- **One source per secret.** Before, sops was truth and OpenBao a copy that could drift.
- **No hand copying.** A rollout once lost a client secret to a failed copy, when `sops set` ran with an empty value. OpenTofu now writes what it creates.
- **Audit.** Every read and write is in OpenBao's audit log, which Wazuh collects.
