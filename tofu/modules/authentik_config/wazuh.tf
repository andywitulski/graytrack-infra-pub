# wazuh.tf - Wazuh dashboard login through Authentik (SAML), as in Wazuh's own Authentik guide.
# The "Roles" attribute carries a backend role the Wazuh indexer and API map to their roles:
#   wazuh-administrators group -> "wazuh-admins"    -> indexer labstack_admin, API administrator
#   wazuh-readonly-users group -> "wazuh-readonly"  -> indexer labstack_readonly, API readonly
# The indexer reads this provider's metadata from a file (output wazuh_saml_metadata), so it never
# has to reach Authentik itself; the browser carries every SAML message.

resource "authentik_group" "wazuh_admins" {
  name = "wazuh-administrators"
}

resource "authentik_group" "wazuh_readonly" {
  name = "wazuh-readonly-users"
}

data "authentik_property_mapping_provider_saml" "username" {
  managed = "goauthentik.io/providers/saml/username"
}

resource "authentik_property_mapping_provider_saml" "wazuh_roles" {
  name      = "Wazuh roles"
  saml_name = "Roles"
  expression = join("\n", [
    "if ak_is_group_member(request.user, name=\"${authentik_group.wazuh_admins.name}\"):",
    "    yield \"wazuh-admins\"",
    "elif ak_is_group_member(request.user, name=\"${authentik_group.wazuh_readonly.name}\"):",
    "    yield \"wazuh-readonly\"",
  ])
}

resource "authentik_provider_saml" "wazuh" {
  name               = "wazuh"
  authorization_flow = local.admin_authorization_flow # device_trust enforce: trusted device + fresh MFA
  invalidation_flow  = data.authentik_flow.invalidation.id
  acs_url            = "${var.wazuh_dashboard_url}/_opendistro/_security/saml/acs"
  issuer_override    = "wazuh-saml"
  audience           = "wazuh-saml"
  sp_binding         = "post"
  signing_kp         = data.authentik_certificate_key_pair.signing.id
  sign_assertion     = true
  property_mappings  = [authentik_property_mapping_provider_saml.wazuh_roles.id]
  name_id_mapping    = data.authentik_property_mapping_provider_saml.username.id
}

resource "authentik_application" "wazuh" {
  name               = "Wazuh"
  slug               = "wazuh"
  protocol_provider  = authentik_provider_saml.wazuh.id
  meta_launch_url    = var.wazuh_dashboard_url
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "wazuh" {
  for_each = {
    admins   = authentik_group.wazuh_admins.id
    readonly = authentik_group.wazuh_readonly.id
  }

  target = authentik_application.wazuh.uuid
  group  = each.value
  order  = each.key == "admins" ? 0 : 1
}

data "authentik_provider_saml_metadata" "wazuh" {
  provider_id = authentik_provider_saml.wazuh.id
}
