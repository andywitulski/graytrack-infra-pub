# Build the platform tier

**Goal:** Stand up `pg01` (state and storage), `bao01` (secrets) and `ca01` (certificates), then move every OpenTofu root onto the state backend.

**Why:** [ADR-0002](../adr/0002-tofu-state-in-postgresql.md), [ADR-0003](../adr/0003-openbao-for-secrets.md), [ADR-0004](../adr/0004-step-ca-for-certificates.md). **Accept with:** [ATP-001](../atp/ATP-001-platform-tier.md).

| Guest | Prod | Dev | Holds |
|---|---|---|---|
| `pg01` | `__MGMT_NET__.22`, VMID 4301 | `__DEV_NET__.60`, VMID 1301 | `tofu_state` (one schema per root), `openbao`, `stepca` |
| `bao01` | `__MGMT_NET__.23`, VMID 4311 | `__DEV_NET__.61`, VMID 1311 | OpenBao: `kv` engine, identities, audit log |
| `ca01` | `__MGMT_NET__.24`, VMID 4321 | `__DEV_NET__.62`, VMID 1321 | step-ca |

Every client reads `tofu/platform/<env>/client.env` through `bin/lib/platform.sh` and pins the CAs in `ansible/files/<env>/`.

## Where each secret lives

| Secret | Location | Needed for |
|---|---|---|
| age key | `~/.config/sops/age/keys.txt` and offline copies | Everything below |
| `tofu_state_pg_password`, `openbao_pg_password`, `openbao_seal_key` | Ansible sops file | `pg01`, OpenBao storage and unseal |
| `TF_VAR_state_passphrase` | `secrets/<env>.enc.env` | Decrypting state |
| `root_token`, `recovery_keys_b64` | `secrets/openbao-<env>.enc.yaml` and paper | `bin/tf-bao`, generate-root |
| AppRole secret IDs | `secrets/openbao-<env>.enc.yaml` | `bin/ap`, `bin/tf-ak` |
| Service secrets | OpenBao `kv/services/<env>/<service>` | Services ([guide](secrets-openbao.md)) |

The only thing that must be kept off-site by hand is the age key. Everything else is in git, or rebuilt from it, or in `pg01`'s backup.

## Prerequisites

- Controller with `sops`, `age`, `tofu`, `jq`, `curl`, and Ansible with the `hvac` library:

  ```bash
  uv tool install ansible-core --with hvac --with-executables-from ansible-lint
  ```
  ```bash
  (cd ansible && ansible-galaxy collection install -r collections/requirements.yml -p collections)
  ```

## Build

1. Generate secrets. Existing keys are kept.
   ```bash
   bin/gen-service-secrets prod
   ```
2. Allow the controller to reach `pg01` and admins to reach `bao01`.
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml
   ```
3. Create the guests on local state, because `pg01` does not exist yet.
   ```bash
   bin/tf-platform prod bootstrap
   ```
4. Configure them: first as root (LXCs start with root keys only), then normally.
   ```bash
   bin/ap prod playbooks/platform.yml --limit platform_guests -e ansible_user=root
   ```
   ```bash
   bin/ap prod playbooks/platform.yml
   ```
   Commit `ansible/files/prod/pg01-ca.pem` and `bao01-ca.pem`.
5. Move the platform root's state into `pg01`. The plan must show no changes; then delete the `terraform.tfstate.migrated-*` file it names.
   ```bash
   bin/tf-platform prod migrate
   ```
   ```bash
   bin/tf-platform prod plan
   ```
6. Initialize OpenBao. The root token and recovery keys go straight into sops; print the recovery keys and store them in the safe.
   ```bash
   bin/bao-init prod
   ```
   ```bash
   sops decrypt --extract '["recovery_keys_b64"]' secrets/openbao-prod.enc.yaml
   ```
   ```bash
   bin/tf-bao prod init && bin/tf-bao prod apply
   ```
   ```bash
   bin/bao-approle prod ansible && bin/bao-approle prod tofu
   ```
   Commit `secrets/openbao-prod.enc.yaml` and `tofu/openbao/<env>/.terraform.lock.hcl`.
7. Continue with [secrets cutover](secrets-openbao.md) and the [certificate authority](certificate-authority.md).

## Move other roots onto the backend

Every root declares `backend "pg"`.

**Local state exists:**
```bash
bin/tf prod init -migrate-state
```
```bash
bin/tf-ak prod init -migrate-state
```

**State was lost:** start empty and adopt what is running. Back up every guest first.
```bash
bin/tf prod init
```
```bash
bin/tf prod plan -out=adopt.plan
```
```bash
bin/tf-adopt prod
```
```bash
bin/tf prod plan -out=adopt.plan
```
The second plan must read *N to import, 0 to add, 0 to destroy*. Then apply `adopt.plan`, delete `imports.tf` and the plan file, and plan again. What remains is real drift.

| In the plan | Meaning | Action |
|---|---|---|
| In-place: comments, rule positions | Attribute drift | Fine |
| Replaced: downloaded images, vendor-data snippet | The API cannot report their source; guests ignore them | Fine |
| Any change in a VM's `agent` block | The provider reboots the VM | **Stop** |
| A guest replaced or destroyed | Code differs from what runs | **Stop**; fix the code first |

### Adopting the identity root

**Never plan or apply `tofu/authentik/<env>` from an empty state.** Generated values would land in state and be pushed out on the next apply.

1. Restore the bind password from OpenBao into state: remove any `random_password.jellyfin_ldap_bind` from state, read `kv/services/prod/tf-authentik`, and import it with `bin/tf-ak prod import`.
2. Import in rounds, objects first and then bindings. Repeat until it says "Nothing left to import".
   ```bash
   bin/tf-ak-adopt prod
   ```
   ```bash
   bin/tf-ak prod apply adopt.plan && rm tofu/authentik/prod/imports.tf
   ```
3. Review the final plan: it should only create what was listed as new. `bin/tf-ak-adopt prod --dedupe` removes duplicate bindings after a confirmation.
4. Compare the LDAP CA fingerprint with `ansible/files/prod/ldap-outpost-ca.pem`. It must not change.

## Verify

```bash
source bin/lib/platform.sh && platform_env prod "$PWD"
```
```bash
psql "$PG_CONN_STR" -c '\dn'
```
```bash
curl -s --cacert "$BAO_CACERT" "$BAO_ADDR/v1/sys/health" | jq '{initialized, sealed, version}'
```
```bash
ssh ansible@pg01 sudo systemctl list-timers labstack-pg-dump.timer
```

## Rotate

| What | How |
|---|---|
| Seal key | Copy `openbao_seal_key` to `openbao_seal_previous_key`; generate a new one; set `openbao_seal_previous_key_id: seal-1` and `openbao_seal_key_id: seal-2`; run the play. After a restart unseals, remove the previous key and ID |
| AppRole secret IDs (expire at 90 days) | `bin/bao-approle prod ansible` |
| Server certificates | Renewed by any play within 60 days of expiry |
| Database passwords | Change in sops and run the play |

For recovery see [Disaster recovery](../runbooks/disaster-recovery.md).
