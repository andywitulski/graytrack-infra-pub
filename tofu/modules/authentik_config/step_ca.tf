# ---------------------------------------------------------------- step-ca: SSH and X.509 certificates for people
# `step ssh login` (bin/ssh-cert <env> login) signs you in here, then step-ca-login on ca01 issues a 16 h
# certificate whose only principal is your Authentik username (roles/step_ca). Who may get one: members
# of the groups bound below, which step-ca checks again from the token's groups claim. Which hosts accept
# it: ssh_ca_people in the Ansible inventory (roles/ssh_ca); Forgejo accepts it for your own account.

resource "authentik_group" "ssh_admins" {
  name = "ssh-admins"
}

# Public client: the step CLI on your workstation is the OAuth client, so a secret could not stay secret.
# PKCE protects the code exchange; the only redirect is the CLI's fixed loopback listener.
resource "authentik_provider_oauth2" "step_ca" {
  name                       = "step-ca"
  client_id                  = "step-ca"
  client_type                = "public"
  authorization_flow         = local.admin_authorization_flow # device_trust enforce: trusted device + fresh MFA
  invalidation_flow          = data.authentik_flow.invalidation.id
  signing_key                = data.authentik_certificate_key_pair.signing.id
  property_mappings          = data.authentik_property_mapping_provider_scope.oidc.ids
  grant_types                = ["authorization_code"]
  include_claims_in_id_token = true # preferred_username, email and groups go into the ID token step-ca reads
  access_token_validity      = "minutes=5"
  allowed_redirect_uris = [
    { matching_mode = "strict", url = "http://${var.step_ca_oidc_listen}", redirect_uri_type = "authorization" },
  ]
}

resource "authentik_application" "step_ca" {
  name              = "SSH certificates (step-ca)"
  slug              = "step-ca" # the discovery URL roles/step_ca uses: /application/o/step-ca/
  protocol_provider = authentik_provider_oauth2.step_ca.id
  meta_description  = "Short-lived SSH certificates for lab hosts and Forgejo (step ssh login)."
}

resource "authentik_policy_binding" "step_ca_access" {
  for_each = {
    "ssh-admins"    = { group = authentik_group.ssh_admins.id, order = 0 }
    "forgejo-users" = { group = authentik_group.forgejo_users.id, order = 1 }
  }

  target = authentik_application.step_ca.uuid
  group  = each.value.group
  order  = each.value.order
}
