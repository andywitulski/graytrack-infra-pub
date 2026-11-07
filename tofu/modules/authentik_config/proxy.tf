# proxy.tf - forward-auth apps behind Caddy (dedicated proxy outpost, port 9010 on the identity host)

locals {
  proxy_apps = {
    music = { name = "Navidrome", host = "https://music.${var.base_domain}", group = "navidrome_users" }
    sync  = { name = "Syncthing", host = "https://sync.${var.base_domain}", group = "syncthing_admins" }
  }
}

resource "authentik_group" "proxy" {
  for_each = local.proxy_apps
  name     = each.value.group
}

resource "authentik_provider_proxy" "app" {
  for_each              = local.proxy_apps
  name                  = "${each.key}-proxy"
  mode                  = "forward_single"
  external_host         = each.value.host
  authorization_flow    = data.authentik_flow.authorization.id
  invalidation_flow     = data.authentik_flow.invalidation.id
  intercept_header_auth = true # lets Subsonic apps send Basic auth with an Authentik app password
}

resource "authentik_application" "proxy" {
  for_each          = local.proxy_apps
  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_proxy.app[each.key].id
  meta_launch_url   = each.value.host
}

resource "authentik_policy_binding" "proxy" {
  for_each = local.proxy_apps
  target   = authentik_application.proxy[each.key].uuid
  group    = authentik_group.proxy[each.key].id
  order    = 0
}

resource "authentik_outpost" "proxy" {
  name               = "proxy"
  type               = "proxy"
  protocol_providers = [for p in authentik_provider_proxy.app : p.id]
}
