# Ansible vars plugin: service secrets from OpenBao (docs/howto/secrets-openbao.md).
#
# Once per run, logs in to OpenBao as the ansible identity, reads every secret under
# kv/services/<env>/ and hands their fields to the play as variables of group "all", under the same names
# the roles have always used (forgejo_db_pass, ...). One login and one read per service for the whole run,
# whatever the number of hosts and tasks; the token is revoked straight after.
#
# bin/ap sets everything it needs:
#   LABSTACK_LAB_ENV               the inventory's environment (prod, labnode, dev); unset: plugin does nothing
#                                   (ansible-lint, ansible-inventory, ad-hoc runs outside bin/ap)
#   LABSTACK_OPENBAO               "off" skips OpenBao (break-glass with bao01 down: only the sops_only keys
#                                   in sops are then defined, enough for playbooks/platform.yml and unifi_*)
#   ANSIBLE_HASHI_VAULT_ADDR, _CA_CERT, _AUTH_METHOD (approle or cert), and _ROLE_ID/_SECRET_ID (approle) or
#   _CERT_AUTH_PUBLIC_KEY/_CERT_AUTH_PRIVATE_KEY (cert): the same login as the community.hashi_vault lookups
#
# Values are marked unsafe, so a secret that happens to contain "{{" is never templated. Besides the
# secrets, it defines openbao_secret_paths ({variable: kv path}, not secret) for playbooks/openbao-smoke.yml.
# Standard library only (no hvac): it runs in the controller's main process, before any fork.

from __future__ import annotations

DOCUMENTATION = """
    name: labstack_openbao
    short_description: Service secrets from OpenBao kv/services/<env>/ as variables of group all
    description:
        - Reads every secret under kv/services/<env>/ once per run and returns their fields as variables.
    options:
      stage:
        ini:
          - key: stage
            section: vars_labstack_openbao
        env:
          - name: ANSIBLE_VARS_PLUGIN_STAGE
    extends_documentation_fragment:
      - vars_plugin_staging
"""

import json
import os
import ssl
import urllib.error
import urllib.request

from ansible.errors import AnsibleError
from ansible.inventory.group import Group
from ansible.plugins.vars import BaseVarsPlugin
from ansible.utils.display import Display
from ansible.utils.unsafe_proxy import wrap_var

display = Display()

_CACHE: dict = {}
_HINT = (
    "Check that bao01 is up and unsealed, then bin/ap again. With bao01 down, LABSTACK_OPENBAO=off bin/ap ... "
    "runs with the sops_only keys alone (enough for playbooks/platform.yml and unifi_*)."
)


class _Bao:
    def __init__(self) -> None:
        self.addr = os.environ.get("ANSIBLE_HASHI_VAULT_ADDR", "").rstrip("/")
        ca = os.environ.get("ANSIBLE_HASHI_VAULT_CA_CERT") or None
        self.ctx = ssl.create_default_context(cafile=ca)
        self.method = os.environ.get("ANSIBLE_HASHI_VAULT_AUTH_METHOD", "")
        if self.method == "cert":
            self.ctx.load_cert_chain(
                os.environ["ANSIBLE_HASHI_VAULT_CERT_AUTH_PUBLIC_KEY"],
                os.environ["ANSIBLE_HASHI_VAULT_CERT_AUTH_PRIVATE_KEY"],
            )
        self.token = ""

    def call(self, method: str, path: str, body: dict | None = None, missing_ok: bool = False):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(f"{self.addr}/v1/{path}", data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if self.token:
            req.add_header("X-Vault-Token", self.token)
        try:
            with urllib.request.urlopen(req, context=self.ctx, timeout=15) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            if missing_ok and e.code == 404:
                return None
            if path.startswith("auth/") and e.code in (400, 403):
                raise AnsibleError(
                    f"OpenBao refused the {self.method} login (HTTP {e.code}): an expired AppRole secret ID "
                    "(bin/bao-approle <platform env> ansible), a certificate it does not accept, or a login from an "
                    "address outside the controllers' (token_bound_cidrs)."
                ) from None
            if e.code == 403:
                raise AnsibleError(f"OpenBao denied {method} {path} to the ansible identity (policy ansible, tofu/modules/openbao_config).") from None
            raise AnsibleError(f"OpenBao {method} {path}: HTTP {e.code}. {_HINT}") from None
        except (urllib.error.URLError, OSError) as e:
            raise AnsibleError(f"OpenBao at {self.addr} unreachable ({e}). {_HINT}") from None

    def login(self) -> None:
        if self.method == "approle":
            body = {
                "role_id": os.environ.get("ANSIBLE_HASHI_VAULT_ROLE_ID", ""),
                "secret_id": os.environ.get("ANSIBLE_HASHI_VAULT_SECRET_ID", ""),
            }
            res = self.call("POST", "auth/approle/login", body)
        elif self.method == "cert":
            res = self.call("POST", "auth/cert/login", {"name": os.environ.get("ANSIBLE_HASHI_VAULT_ROLE_ID", "ansible")})
        else:
            raise AnsibleError(f"no OpenBao login method in this run (ANSIBLE_HASHI_VAULT_AUTH_METHOD={self.method!r}). {_HINT}")
        self.token = res["auth"]["client_token"]

    def revoke(self) -> None:
        try:
            self.call("POST", "auth/token/revoke-self", {})
        except AnsibleError:
            pass  # expires on its own (30 minutes)
        self.token = ""


def _load(env: str) -> dict:
    bao = _Bao()
    if not bao.addr:
        raise AnsibleError(f"ANSIBLE_HASHI_VAULT_ADDR is not set. {_HINT}")
    bao.login()
    try:
        listing = bao.call("LIST", f"kv/metadata/services/{env}", missing_ok=True) or {}
        names = sorted(k for k in listing.get("data", {}).get("keys", []) if not k.endswith("/"))
        values: dict = {}
        paths: dict = {}
        for name in names:
            res = bao.call("GET", f"kv/data/services/{env}/{name}", missing_ok=True) or {}
            for key, value in ((res.get("data") or {}).get("data") or {}).items():
                if key in values:
                    raise AnsibleError(f"{key} is stored twice: kv/{paths[key]} and kv/services/{env}/{name}. Remove one.")
                values[key] = value
                paths[key] = f"services/{env}/{name}"
    finally:
        bao.revoke()
    display.v(f"labstack_openbao: {len(values)} secrets from kv/services/{env}/ ({len(names)} services)")
    out = {k: wrap_var(v) for k, v in values.items()}
    out["openbao_secret_paths"] = paths
    return out


class VarsModule(BaseVarsPlugin):
    REQUIRES_ENABLED = True

    def get_vars(self, loader, path, entities, cache=True):
        super().get_vars(loader, path, entities)
        if not any(isinstance(e, Group) and e.name == "all" for e in entities):
            return {}
        env = os.environ.get("LABSTACK_LAB_ENV", "")
        if not env:
            return {}
        if os.environ.get("LABSTACK_OPENBAO", "") == "off":
            if "off" not in _CACHE:
                display.warning("LABSTACK_OPENBAO=off: no secrets from OpenBao in this run, only the sops_only keys from sops")
                _CACHE["off"] = True
            return {}
        if env not in _CACHE:
            _CACHE[env] = _load(env)
        return dict(_CACHE[env])
