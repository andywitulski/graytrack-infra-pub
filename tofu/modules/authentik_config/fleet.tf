# fleet.tf - Fleet console (device management) sign-in through Authentik (SAML), as in Fleet's own guide.
# Fleet Free has no just-in-time provisioning: a Fleet user with the same email must exist (the first admin,
# made with fleetctl setup), and this login only proves who it is. Only fleet-admins get through.
# Fleet reads the metadata from its GitOps file (fleet/default.yml, $FLEET_SSO_METADATA from the output
# fleet_saml_metadata), so it never has to reach Authentik itself.

resource "authentik_group" "fleet_admins" {
  name = "fleet-admins"
}

data "authentik_property_mapping_provider_saml" "email" {
  managed = "goauthentik.io/providers/saml/email"
}

data "authentik_property_mapping_provider_saml" "name" {
  managed = "goauthentik.io/providers/saml/name"
}

resource "authentik_provider_saml" "fleet" {
  name               = "fleet"
  authorization_flow = local.admin_authorization_flow # device_trust enforce: trusted device + fresh MFA
  invalidation_flow  = data.authentik_flow.invalidation.id
  acs_url            = "https://mdm.${var.base_domain}/api/v1/fleet/sso/callback"
  issuer_override    = "authentik"
  # Fleet's SP entity ID (sso_settings.entity_id in fleet/default.yml)
  audience          = "fleet"
  sp_binding        = "post"
  signing_kp        = data.authentik_certificate_key_pair.signing.id
  sign_assertion    = true
  sign_response     = true
  name_id_mapping   = data.authentik_property_mapping_provider_saml.email.id
  property_mappings = [data.authentik_property_mapping_provider_saml.name.id]
}

resource "authentik_application" "fleet" {
  name               = "Fleet (devices)"
  slug               = "fleet"
  protocol_provider  = authentik_provider_saml.fleet.id
  meta_launch_url    = "https://mdm.${var.base_domain}/"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "fleet" {
  target = authentik_application.fleet.uuid
  group  = authentik_group.fleet_admins.id
  order  = 0
}

data "authentik_provider_saml_metadata" "fleet" {
  provider_id = authentik_provider_saml.fleet.id
}
