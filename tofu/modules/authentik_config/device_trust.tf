# device_trust.tf - a registered device as an authentication factor (ADR-0006, docs/howto/device-trust.md).
#
# A device is a client certificate from ca01 whose private key cannot leave the machine: the Secure Enclave
# on the admin workstation, the TPM on paw01. Caddy on auth.<domain> asks for it (client_auth verify_if_given, lab root
# and intermediate only) and passes one thing upstream: the SHA-256 of the verified certificate's public key,
# as X-Labstack-Device-Key. A value sent by the client is dropped first (roles/caddy). The device counts when
# that key is registered below for the user signing in. The certificate proves the CA issued it recently; the
# registration decides that this key belongs to this person. Unregistering works at the next apply.
#
# Modes (var.device_trust):
#   off      nothing below exists
#   enroll   the step-ca-device application (a fresh second factor, then a device certificate from
#            step-ca-login) and the device policy. Sign-in is unchanged. Enroll and register first.
#   enforce  tiered sign-in. A registered device replaces the second factor when signing in. Admin
#            applications (Proxmox, Wazuh, Fleet, SSH certificates) need a registered device AND a fresh second
#            factor; from any other device they are refused.
#
# The header can only be trusted if Authentik is reachable through Caddy alone. Before enforce:
# firewall_enforce = true in tofu/envs/<env>/firewall.tf, so idp01:9000 answers edge01 only.

locals {
  device_trust_on      = var.device_trust != "off"
  device_trust_enforce = var.device_trust == "enforce"

  # username => registered key hashes (lowercase hex), rendered into the policy as a literal
  device_keys = {
    for owner in distinct([for d in values(var.trusted_devices) : d.owner]) :
    owner => sort([for d in values(var.trusted_devices) : lower(d.key_sha256) if d.owner == owner])
  }

  # Admin applications authorize through the device-and-fresh-MFA flow once enforced
  admin_authorization_flow = local.device_trust_enforce ? authentik_flow.admin_authorization[0].uuid : data.authentik_flow.authorization.id
}

# ---------------------------------------------------------------- the device check
# During sign-in the user is the pending one; during authorization it is the signed-in user.
resource "authentik_policy_expression" "trusted_device" {
  count = local.device_trust_on ? 1 : 0
  name  = "labstack-trusted-device"

  expression = <<-EOT
    # Managed by OpenTofu (labstack-infra, device_trust.tf). True when the client key Caddy verified on this
    # request is registered to the user being authenticated or signed in.
    devices = ${jsonencode(local.device_keys)}
    http = request.http_request
    key = (http.headers.get("X-Labstack-Device-Key", "") if http is not None else "").strip().lower()
    user = request.context.get("pending_user") or request.user
    username = getattr(user, "username", "") or ""
    trusted = bool(key) and key in devices.get(username, [])
    ak_logger.info("labstack device check", user=username, presented=key[:16], trusted=trusted)
    return trusted
  EOT
}

# ---------------------------------------------------------------- a fresh second factor
# last_auth_threshold seconds=0: asked every time, whatever the session already did
resource "authentik_stage_authenticator_validate" "fresh_mfa" {
  count                 = local.device_trust_on ? 1 : 0
  name                  = "labstack-fresh-mfa"
  device_classes        = ["totp", "webauthn"]
  not_configured_action = "deny"
  last_auth_threshold   = "seconds=0"
}

# Enrolling a device: a fresh second factor, never a device (the first device has none to show)
resource "authentik_flow" "reauth_authorization" {
  count         = local.device_trust_on ? 1 : 0
  name          = "labstack-reauth-authorization"
  title         = "Confirm it is you"
  slug          = "labstack-reauth-authorization"
  designation   = "authorization"
  denied_action = "message"
}

resource "authentik_flow_stage_binding" "reauth_mfa" {
  count  = local.device_trust_on ? 1 : 0
  target = authentik_flow.reauth_authorization[0].uuid
  stage  = authentik_stage_authenticator_validate.fresh_mfa[0].id
  order  = 10
}

# ---------------------------------------------------------------- device certificates (step-ca-login)
# Same shape as step_ca.tf: public client, PKCE, the step CLI's fixed loopback callback. A separate client
# ID because step-ca keys OIDC provisioners by it (roles/step_ca, provisioner authentik-device).
resource "authentik_provider_oauth2" "step_ca_device" {
  count                      = local.device_trust_on ? 1 : 0
  name                       = "step-ca-device"
  client_id                  = "step-ca-device"
  client_type                = "public"
  authorization_flow         = authentik_flow.reauth_authorization[0].uuid
  invalidation_flow          = data.authentik_flow.invalidation.id
  signing_key                = data.authentik_certificate_key_pair.signing.id
  property_mappings          = data.authentik_property_mapping_provider_scope.oidc.ids
  grant_types                = ["authorization_code"]
  include_claims_in_id_token = true
  access_token_validity      = "minutes=5"
  allowed_redirect_uris = [
    { matching_mode = "strict", url = "http://${var.step_ca_oidc_listen}", redirect_uri_type = "authorization" },
  ]
}

resource "authentik_application" "step_ca_device" {
  count             = local.device_trust_on ? 1 : 0
  name              = "Device certificates (step-ca)"
  slug              = "step-ca-device" # discovery URL roles/step_ca uses: /application/o/step-ca-device/
  protocol_provider = authentik_provider_oauth2.step_ca_device[0].id
  meta_description  = "Client certificates for registered devices (bin/device-cert)."
}

resource "authentik_policy_binding" "step_ca_device_access" {
  count  = local.device_trust_on ? 1 : 0
  target = authentik_application.step_ca_device[0].uuid
  group  = authentik_group.ssh_admins.id
  order  = 0
}

# ---------------------------------------------------------------- enforce: sign-in
# The second factor at sign-in runs unless a registered device was presented (mfa.tf, authentication_mfa)
resource "authentik_policy_binding" "mfa_unless_device" {
  count  = local.device_trust_enforce ? 1 : 0
  target = authentik_flow_stage_binding.authentication_mfa.id
  policy = authentik_policy_expression.trusted_device[0].id
  order  = 0
  negate = true
}

# ---------------------------------------------------------------- enforce: admin applications
# No registered device: refused. Registered device: a fresh second factor, every time.
resource "authentik_flow" "admin_authorization" {
  count         = local.device_trust_enforce ? 1 : 0
  name          = "labstack-admin-authorization"
  title         = "Admin access: trusted device and second factor"
  slug          = "labstack-admin-authorization"
  designation   = "authorization"
  denied_action = "message"
}

resource "authentik_stage_deny" "untrusted_device" {
  count = local.device_trust_enforce ? 1 : 0
  name  = "labstack-untrusted-device"
}

resource "authentik_flow_stage_binding" "admin_device" {
  count                = local.device_trust_enforce ? 1 : 0
  target               = authentik_flow.admin_authorization[0].uuid
  stage                = authentik_stage_deny.untrusted_device[0].id
  order                = 10
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

# The deny stage runs when the device check fails
resource "authentik_policy_binding" "admin_device" {
  count  = local.device_trust_enforce ? 1 : 0
  target = authentik_flow_stage_binding.admin_device[0].id
  policy = authentik_policy_expression.trusted_device[0].id
  order  = 0
  negate = true
}

resource "authentik_flow_stage_binding" "admin_mfa" {
  count  = local.device_trust_enforce ? 1 : 0
  target = authentik_flow.admin_authorization[0].uuid
  stage  = authentik_stage_authenticator_validate.fresh_mfa[0].id
  order  = 20
}
