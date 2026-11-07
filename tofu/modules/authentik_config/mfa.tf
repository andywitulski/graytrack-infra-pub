# mfa.tf - sign-in for the public auth.<domain>: password plus a second factor (TOTP or WebAuthn),
# enrolled at first sign-in, and a reputation policy that refuses an IP or username after repeated
# failures. Applied through a brand for auth.<domain>, so the built-in default flow stays untouched
# (the LDAP outpost binds through it; Jellyfin cannot answer a second factor).
# Lockout recovery from the LAN: docker compose exec server ak create_recovery_key 1 akadmin (on idp01).

data "authentik_stage" "identification" {
  name = "default-authentication-identification"
}

data "authentik_stage" "password" {
  name = "default-authentication-password"
}

data "authentik_stage" "login" {
  name = "default-authentication-login"
}

data "authentik_flow" "logout" {
  slug = "default-invalidation-flow"
}

resource "authentik_stage_authenticator_totp" "totp" {
  name          = "labstack-totp-setup"
  friendly_name = "Authenticator app"
  digits        = "6"
}

resource "authentik_stage_authenticator_webauthn" "webauthn" {
  name              = "labstack-webauthn-setup"
  friendly_name     = "Security key or passkey"
  user_verification = "preferred"
}

resource "authentik_stage_authenticator_validate" "mfa" {
  name                  = "labstack-mfa"
  device_classes        = ["totp", "webauthn"]
  not_configured_action = "configure" # first sign-in without a device enrolls one
  configuration_stages = [
    authentik_stage_authenticator_totp.totp.id,
    authentik_stage_authenticator_webauthn.webauthn.id,
  ]
}

resource "authentik_flow" "authentication" {
  name        = "labstack-authentication"
  title       = "Sign in to labstack"
  slug        = "labstack-authentication"
  designation = "authentication"
  # a refused sign-in (reputation) shows the denial and stops there
  denied_action = "message"
}

resource "authentik_flow_stage_binding" "authentication" {
  for_each = {
    10  = data.authentik_stage.identification.id
    20  = data.authentik_stage.password.id
    100 = data.authentik_stage.login.id
  }
  target = authentik_flow.authentication.uuid
  stage  = each.value
  order  = tonumber(each.key)
}

# The second factor, bound on its own: with device_trust = "enforce" a registered device skips it
# (device_trust.tf, mfa_unless_device). Evaluated when reached rather than when the flow is planned,
# because only after identification is the user known. Without that policy binding it always runs.
resource "authentik_flow_stage_binding" "authentication_mfa" {
  target               = authentik_flow.authentication.uuid
  stage                = authentik_stage_authenticator_validate.mfa.id
  order                = 30
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

moved {
  from = authentik_flow_stage_binding.authentication["30"]
  to   = authentik_flow_stage_binding.authentication_mfa
}

# Score drops by one per failed sign-in (per IP and per username). A reputation policy PASSES when the
# score is at or below its threshold (it is built to flag bad actors), so the flow binding is negated:
# the flow refuses only addresses and usernames that have sunk to -5.
resource "authentik_policy_reputation" "signin" {
  name           = "labstack-signin-reputation"
  check_ip       = true
  check_username = true
  threshold      = -5
}

resource "authentik_policy_binding" "signin_reputation" {
  target = authentik_flow.authentication.uuid
  policy = authentik_policy_reputation.signin.id
  order  = 0
  negate = true
}

resource "authentik_brand" "auth" {
  domain         = "auth.${var.base_domain}"
  default        = false
  branding_title = "labstack"
  # Authentik's own defaults, stated: since 2026.8 the API reports them, so leaving them out makes every
  # plan clear them (null) and Authentik set them again
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  flow_authentication = authentik_flow.authentication.uuid
  flow_invalidation   = data.authentik_flow.logout.id
}
