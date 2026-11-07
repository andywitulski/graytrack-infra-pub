# shellcheck shell=bash
# Sourced by bin/tf, bin/tf-ak, bin/tf-platform, bin/tf-bao, bin/ap, bin/bao-*, bin/ca-init and bin/ssh-cert.
# Not run on its own.
#
# platform_env <env> <repo_root>
#   Exports what a client needs to reach the platform tier of <env> (tofu/platform/<env>/client.env):
#   - PG_CONN_STR and PGPASSWORD: the OpenTofu pg backend (state in pg01), TLS verified against the
#     committed CA (sslmode=verify-full), password from sops (tofu_state_pg_password).
#   - BAO_ADDR / BAO_CACERT and VAULT_ADDR / VAULT_CACERT: OpenBao on bao01, for curl, the bao CLI and
#     the vault provider. PLATFORM_BAO_AUTH: how bin/ap logs in (approle or cert).
#   - PLATFORM_CA_URL, PLATFORM_CA_LOGIN_URL, PLATFORM_CA_ROOT: step-ca on ca01 (automation, people).
#     LABSTACK_SSH_DIR: where bin/ssh-cert keeps this env's short-lived keys and certificates.
#   Nothing is printed except notes on stderr, nothing is written to disk.
# platform_of <env>: whose platform tier (pg01, bao01, ca01) an environment uses. labnode is a standalone
# node on the prod network: its state lives in prod's pg01 (schema labnode), its hosts trust prod's CA.
platform_of() {
  case "$1" in labnode) echo prod ;; *) echo "$1" ;; esac
}

platform_env() {
  local env=$1 root=$2
  local client="$root/tofu/platform/$env/client.env"
  local secrets="$root/ansible/inventories/$env/group_vars/all/secrets.sops.yml"
  local pw

  [[ -f $client ]] || { echo "missing $client" >&2; return 1; }
  # shellcheck source=/dev/null
  source "$client"

  PLATFORM_PG_CA="$root/$PLATFORM_PG_CA"
  # The trust bundle exists once roles/openbao has run with ca01 in place; before that, the per-host CA
  [[ -f $root/$PLATFORM_BAO_CA ]] || PLATFORM_BAO_CA=${PLATFORM_BAO_CA/-trust.pem/-ca.pem}
  PLATFORM_BAO_CA="$root/$PLATFORM_BAO_CA"
  export PLATFORM_PG_CA PLATFORM_BAO_CA

  # shellcheck disable=SC2153 # set by client.env
  export PG_CONN_STR="postgres://${PLATFORM_PG_USER}@${PLATFORM_PG_HOST}:${PLATFORM_PG_PORT}/${PLATFORM_PG_DB}?sslmode=verify-full&sslrootcert=${PLATFORM_PG_CA}&connect_timeout=10"
  if pw=$(sops decrypt --extract '["tofu_state_pg_password"]' "$secrets" 2>/dev/null) && [[ -n $pw && $pw != PENDING ]]; then
    export PGPASSWORD=$pw
  else
    unset PGPASSWORD
  fi

  export BAO_ADDR=$PLATFORM_BAO_ADDR BAO_CACERT=$PLATFORM_BAO_CA
  export VAULT_ADDR=$PLATFORM_BAO_ADDR VAULT_CACERT=$PLATFORM_BAO_CA
  export PLATFORM_BAO_AUTH=${PLATFORM_BAO_AUTH:-approle}

  PLATFORM_CA_ROOT="$root/${PLATFORM_CA_ROOT:-ansible/files/$env/ca01-root.pem}"
  PLATFORM_CA_LOGIN_URL="${PLATFORM_CA_URL%/}:8443"
  export PLATFORM_CA_URL PLATFORM_CA_LOGIN_URL PLATFORM_CA_ROOT
  export LABSTACK_ENV=$env LABSTACK_SSH_DIR="$HOME/.ssh/labstack/$env"
}

# ---------------------------------------------------------------- portable helpers (Linux and macOS)
# The controllers are a admin workstation and paw01 (Linux), so nothing here may rely on GNU-only options.
gt_tmpbase() { printf '%s' "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"; }
gt_tmpdir() { mktemp -d "$(gt_tmpbase)/labstack.XXXXXX"; }
gt_tmpfile() { mktemp "$(gt_tmpbase)/labstack.XXXXXX"; }
# Overwrite, then remove (shred on Linux, rm -P on macOS, plain rm as the last resort)
gt_shred() {
  local f
  for f in "$@"; do
    [[ -f $f ]] || continue
    shred -u "$f" 2> /dev/null || rm -P "$f" 2> /dev/null || rm -f "$f"
  done
}
gt_shred_dir() {
  [[ -d ${1:-} ]] || return 0
  local f
  while IFS= read -r -d '' f; do gt_shred "$f"; done < <(find "$1" -type f -print0)
  rm -rf "$1"
}
# Seconds since the epoch for a time as ssh-keygen -L prints it (local, 2026-10-29T06:56:44)
gt_epoch() {
  date -d "$1" +%s 2> /dev/null || date -j -f '%Y-%m-%dT%H:%M:%S' "$1" +%s 2> /dev/null
}

# ssh_ca_ready <env> <repo_root>: true once bin/ca-init has run for <env> and the step CLI is installed
ssh_ca_ready() {
  [[ -f "$2/ansible/files/$1/ca01-ssh-user-ca.pub" && -f "$2/ansible/files/$1/ca01-root.pem" ]] && command -v step > /dev/null
}

# tofu_cert_agent <env> <repo_root>: a private ssh-agent holding only the tofu certificate (bin/ssh-cert),
# for the Proxmox provider's SSH (agent = true). Nothing else from your own agent is offered, so the
# nodes' MaxAuthTries never runs out on unrelated keys. Stop it with tofu_cert_agent_stop.
# Falls back to your own agent (the static tofu key) when the CA is not set up or not reachable, unless
# LABSTACK_SSH=cert demands the certificate.
tofu_cert_agent() {
  local env=$1 root=$2 sock
  [[ ${LABSTACK_SSH:-} == static ]] && { tofu_static_key_loaded "$root"; return; }
  if ! ssh_ca_ready "$env" "$root"; then
    [[ ${LABSTACK_SSH:-} == cert ]] && { echo "LABSTACK_SSH=cert, but the SSH CA is not set up for $env" >&2; return 1; }
    tofu_static_key_loaded "$root"
    return
  fi
  if ! "$root/bin/ssh-cert" "$env" tofu --quiet; then
    [[ ${LABSTACK_SSH:-} == cert ]] && return 1
    echo "note: no tofu certificate (ca01 unreachable?), using your own ssh-agent and the static key" >&2
    tofu_static_key_loaded "$root"
    return
  fi
  sock="$(gt_tmpbase)/labstack-agent.$$.$RANDOM"
  eval "$(ssh-agent -s -a "$sock")" > /dev/null
  TOFU_CERT_AGENT_PID=$SSH_AGENT_PID
  ssh-add -q "$LABSTACK_SSH_DIR/tofu" 2> /dev/null # adds tofu-cert.pub alongside the key
}

# tofu_static_key_loaded <repo_root>: without a certificate the provider's SSH (snippet uploads, disk
# imports) uses your own ssh-agent, and finds out only mid-apply that the agent lacks the tofu key, after
# it has already deleted what it was replacing. Refuse up front instead.
tofu_static_key_loaded() {
  local want
  want=$(cut -d' ' -f2 "$1/ansible/files/pubkeys/tofu.pub")
  if ! ssh-add -L 2> /dev/null | cut -d' ' -f2 | grep -qxF "$want"; then
    echo "ssh-agent does not hold the tofu key (ansible/files/pubkeys/tofu.pub), and there is no tofu certificate." >&2
    echo "The Proxmox provider needs it for snippet uploads. Load it: ssh-add <the matching private key>" >&2
    return 1
  fi
}

tofu_cert_agent_stop() {
  [[ -n ${TOFU_CERT_AGENT_PID:-} ]] && SSH_AGENT_PID=$TOFU_CERT_AGENT_PID ssh-agent -k > /dev/null 2>&1
  unset TOFU_CERT_AGENT_PID
}

# platform_need_backend: call before a tofu command that touches state. Explains what is missing instead
# of leaving the pg backend to fail with a TLS or authentication error.
platform_need_backend() {
  local ok=0
  if [[ ! -f $PLATFORM_PG_CA ]]; then
    echo "state backend: ${PLATFORM_PG_CA#"$PWD"/} is missing. playbooks/platform.yml writes it when it configures pg01." >&2
    ok=1
  fi
  if [[ -z ${PGPASSWORD:-} ]]; then
    echo "state backend: tofu_state_pg_password is not in sops yet (bin/gen-service-secrets <env>)." >&2
    ok=1
  fi
  return $ok
}

# platform_cmd_needs_backend <tofu args...>: true unless the command works without state
platform_cmd_needs_backend() {
  case "${1:-}" in
    fmt | validate | version | providers | -help | --help | -version | "") return 1 ;;
  esac
  [[ " $* " == *" -backend=false "* ]] && return 1
  return 0
}

# bao_api <METHOD> <path> [json body]: OpenBao HTTP API with the CA from client.env. The token (BAO_TOKEN,
# when set) and the body travel through pipes, never on the command line where ps would show them.
bao_api() {
  local method=$1 path=$2 body=${3:-} hdr=''
  local curl_args=(-fsS --connect-timeout 10 --cacert "$BAO_CACERT" -X "$method" -H 'Content-Type: application/json')
  [[ -n ${BAO_TOKEN:-} ]] && hdr="X-Vault-Token: $BAO_TOKEN"
  # Process substitutions stay inside the curl command itself: one expanded earlier would be closed by now
  if [[ -n $body ]]; then
    curl "${curl_args[@]}" -H @<(printf '%s\n' "$hdr") --data-binary @<(printf '%s' "$body") "$BAO_ADDR/v1/$path"
  else
    curl "${curl_args[@]}" -H @<(printf '%s\n' "$hdr") "$BAO_ADDR/v1/$path"
  fi
}

# bao_root_token <env> <repo_root>: sets BAO_TOKEN from secrets/openbao-<env>.enc.yaml (bin/bao-init)
bao_root_token() {
  local f="$2/secrets/openbao-$1.enc.yaml"
  [[ -f $f ]] || { echo "missing $f: initialize OpenBao first (bin/bao-init $1)" >&2; return 1; }
  BAO_TOKEN=$(sops decrypt --extract '["root_token"]' "$f")
}

# ---------------------------------------------------------------- service secrets in OpenBao
# Layout (docs/howto/secrets-openbao.md): kv/services/<env>/<service>, one kv secret per service, whose
# fields are the variable names Ansible uses (forgejo_db_pass lives in kv/services/prod/forgejo). The
# service is the key name up to the first underscore. kv/services/<env>/tf-authentik belongs to OpenTofu.

# secrets_policy <repo_root>: GT_SOPS_ONLY and GT_TOFU_OWNED, the key regexes from secrets/policy.yml
secrets_policy() {
  local f="$1/secrets/policy.yml"
  GT_SOPS_ONLY=$(sed -n "s/^sops_only: '\(.*\)'\$/\1/p" "$f")
  GT_TOFU_OWNED=$(sed -n "s/^tofu_owned: '\(.*\)'\$/\1/p" "$f")
  [[ -n $GT_SOPS_ONLY && -n $GT_TOFU_OWNED ]] || { echo "cannot read the key rules from $f" >&2; return 1; }
}

# secrets_backend <env> <repo_root>: prints openbao once bin/bao-import-sops <env> --cutover has run
# (secrets_file_version 2), sops before that
secrets_backend() {
  local v
  v=$(sops decrypt --extract '["secrets_file_version"]' "$2/ansible/inventories/$1/group_vars/all/secrets.sops.yml" 2> /dev/null || echo 1)
  [[ $v == 2 ]] && echo openbao || echo sops
}

# bao_env_load <env>: every service secret of <env> into GT_BAO_SECRETS (one JSON object, {key: value}) and
# where each lives into GT_BAO_PATHS ({key: path}, not secret). A key stored under two services is an error:
# consumers would get whichever came last. Needs BAO_TOKEN. Secret values only ever move through pipes.
bao_env_load() {
  local env=$1 names name data out='{}' dup
  GT_BAO_PATHS='{}'
  names=$(bao_api LIST "kv/metadata/services/$env" 2> /dev/null | jq -r '.data.keys[]? | select(endswith("/") | not)' || true)
  for name in $names; do
    data=$(bao_api GET "kv/data/services/$env/$name" 2> /dev/null | jq -c '.data.data // {}') || data='{}'
    dup=$(printf '%s\n%s\n' "$out" "$data" | jq -rs '(.[0] | keys) - ((.[0] | keys) - (.[1] | keys)) | join(", ")')
    [[ -z $dup ]] || { echo "kv/services/$env: $dup stored in more than one service (one is $name)" >&2; return 1; }
    out=$(printf '%s\n%s\n' "$out" "$data" | jq -cs '.[0] + .[1]')
    GT_BAO_PATHS=$(printf '%s\n' "$data" | jq -c --argjson p "$GT_BAO_PATHS" --arg n "services/$env/$name" '$p + (keys | map({(.): $n}) | add // {})')
  done
  # shellcheck disable=SC2034 # read by the callers
  GT_BAO_SECRETS=$out
}

# bao_kv_patch <path>: merges the JSON object on stdin into kv/data/<path> (other fields are kept), with
# check-and-set so two writers cannot silently overwrite each other. Needs BAO_TOKEN.
bao_kv_patch() {
  local path=$1 fields cur ver body
  fields=$(cat)
  cur=$(bao_api GET "kv/data/$path" 2> /dev/null) || cur='{}'
  ver=$(printf '%s' "$cur" | jq -r '.data.metadata.version // 0')
  body=$(printf '%s\n%s\n' "$cur" "$fields" | jq -cs --argjson v "$ver" '{options: {cas: $v}, data: ((.[0].data.data // {}) + .[1])}')
  bao_api POST "kv/data/$path" "$body" > /dev/null
}

# bao_kv_unset <path> <key>: removes one field (the secret itself goes once its last field is gone)
bao_kv_unset() {
  local path=$1 key=$2 cur ver body
  cur=$(bao_api GET "kv/data/$path" 2> /dev/null) || return 0
  ver=$(printf '%s' "$cur" | jq -r '.data.metadata.version')
  if printf '%s' "$cur" | jq -e --arg k "$key" '.data.data | del(.[$k]) | length == 0' > /dev/null; then
    bao_api DELETE "kv/metadata/$path" > /dev/null
  else
    body=$(printf '%s' "$cur" | jq -c --argjson v "$ver" --arg k "$key" '{options: {cas: $v}, data: (.data.data | del(.[$k]))}')
    bao_api POST "kv/data/$path" "$body" > /dev/null
  fi
}

# bao_approle_login <env> <repo_root> <role>: BAO_TOKEN for an AppRole identity (bin/bao-approle <env> <role>),
# 30 minutes. Returns 1 without output if that identity has no secret ID in sops.
bao_approle_login() {
  local f="$2/secrets/openbao-$1.enc.yaml" rid sid
  rid=$(sops decrypt --extract "[\"approle_${3}_role_id\"]" "$f" 2> /dev/null) || return 1
  sid=$(sops decrypt --extract "[\"approle_${3}_secret_id\"]" "$f" 2> /dev/null) || return 1
  BAO_TOKEN=$(BAO_TOKEN='' bao_api POST auth/approle/login "$(printf '%s\n%s\n' "$rid" "$sid" | jq -Rnc '[inputs] | {role_id: .[0], secret_id: .[1]}')" |
    jq -r '.auth.client_token // empty')
  unset rid sid
  [[ -n $BAO_TOKEN ]]
}

# platform_prod_confirm <what>: the same guard bin/tf uses for prod changes
platform_prod_confirm() {
  [[ ${CI:-} == true ]] && return 0
  local ok
  read -r -p "PROD $1. Type 'prod' to continue: " ok
  [[ $ok == prod ]] || { echo "aborted" >&2; exit 1; }
}
