# Host firewalls for the platform guests, enforced by Proxmox on the node (same model as
# tofu/envs/prod/firewall.tf). Inbound only; outbound stays with the UniFi zone policy.
#
# The ipsets used here (+controller, +admins) are cluster-wide and owned by tofu/envs/prod/firewall.tf.
# They are referenced by name, not managed twice. If that root is ever rebuilt from scratch, apply it
# before this one, or these rules point at sets that do not exist and Proxmox rejects them.
#
# bao01 to pg01 is same-VLAN traffic: it never reaches the gateway, so this is the only filter on it.

locals {
  guest_ip = { for k, v in local.platform_lxcs : k => split("/", v.ip)[0] }

  # Rule shorthand: [proto, ports, source (address, CIDR or +ipset), comment]
  ssh_ping = [
    ["tcp", "22", "+controller", "Ansible"],
    ["icmp", "", "+controller", "ping from the controller"],
  ]
  guest_rules = {
    pg01 = [
      ["tcp", "5432", "+controller", "OpenTofu state backend (bin/tf*)"],
      ["tcp", "5432", local.guest_ip.bao01, "OpenBao storage"],
      ["tcp", "5432", local.guest_ip.ca01, "step-ca database"],
    ]
    bao01 = [
      ["tcp", "8200", "+admins", "OpenBao API and UI"],
    ]
    # Certificates and SSH logins: admins (step ssh login, step ca) and the controller (automation certs,
    # host certificates). The guests never call ca01: the controller signs their host keys and pushes the
    # certificates (roles/ssh_ca), so no zone needs a path to the CA.
    ca01 = [
      ["tcp", "443", "+admins", "step-ca: automation and host certificates"],
      ["tcp", "8443", "+admins", "step-ca-login: people (step ssh login via Authentik)"],
    ]
  }

  # Same chatter tofu/envs/prod drops quietly on every guest
  quiet_drop = [
    ["udp", "5353", "mDNS (gateway, IPv4 and IPv6)"],
    ["udp", "10001", "UniFi device discovery broadcast"],
    ["udp", "21027", "Syncthing local discovery broadcast"],
    ["igmp", "", "IGMP membership queries"],
  ]
}

check "every_platform_guest_has_rules" {
  assert {
    condition     = length(setsubtract(keys(local.platform_lxcs), keys(local.guest_rules))) == 0
    error_message = "Platform guests without firewall rules: ${join(", ", setsubtract(keys(local.platform_lxcs), keys(local.guest_rules)))}."
  }
}

resource "proxmox_virtual_environment_firewall_options" "guest" {
  for_each = module.platform_lxc

  node_name    = each.value.node
  container_id = each.value.vm_id

  enabled       = true
  input_policy  = var.firewall_enforce ? "DROP" : "ACCEPT"
  output_policy = "ACCEPT"
  log_level_in  = var.firewall_enforce ? "info" : "nolog"
  dhcp          = false
  ndp           = true
  macfilter     = true
  ipfilter      = false
}

resource "proxmox_virtual_environment_firewall_rules" "guest" {
  for_each = module.platform_lxc

  node_name    = each.value.node
  container_id = each.value.vm_id

  dynamic "rule" {
    for_each = concat(local.guest_rules[each.key], local.ssh_ping)
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = rule.value[0]
      dport   = rule.value[1] == "" ? null : rule.value[1]
      source  = rule.value[2] == "" ? null : rule.value[2]
      comment = rule.value[3]
    }
  }

  dynamic "rule" {
    for_each = local.quiet_drop
    content {
      type    = "in"
      action  = "DROP"
      proto   = rule.value[0]
      dport   = rule.value[1] == "" ? null : rule.value[1]
      log     = "nolog"
      comment = rule.value[2]
    }
  }

  dynamic "rule" {
    for_each = var.firewall_enforce ? [] : [1]
    content {
      type    = "in"
      action  = "ACCEPT"
      log     = "info"
      comment = "would-drop (audit mode, firewall_enforce = false)"
    }
  }
}
