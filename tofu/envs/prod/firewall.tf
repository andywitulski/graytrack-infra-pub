# Host firewalls for every service guest, enforced by Proxmox on the node (the guest's own root cannot
# turn it off, and Docker's iptables inside a guest do not matter). Inbound only: each guest lists what
# may reach it; outbound stays with the UniFi zone policy. Same-VLAN traffic, which never passes the
# gateway, is now filtered too (media01 to idp01 LDAP, sync01 to git01 SSH, nodes to pbs01).
#
# Addresses come from the UniFi zone policy (ansible/network/zone_policy.yml) and from this env's guest
# definitions, so nothing is typed twice.
#
# Rollout: firewall_enforce = false first. Every guest then ACCEPTs everything, but traffic that no rule
# covers is logged ("would-drop") in /var/log/pve-firewall.log on its node. When that log stays quiet
# for normal use, set it to true: the policy becomes DROP and the logging rule goes away.

variable "firewall_enforce" {
  description = "false: audit mode (accept and log unmatched inbound). true: drop unmatched inbound."
  type        = bool
  default     = false
}

locals {
  zp = yamldecode(file("${path.module}/../../../ansible/network/zone_policy.yml"))

  guest_ip = merge(
    { for k, v in local.service_vms : k => split("/", v.ip)[0] },
    { for k, v in local.service_lxcs : k => split("/", v.ip)[0] },
    { siem01 = split("/", module.siem01.service_ipv4)[0] },
  )

  guests = merge(
    { for k, v in local.service_vms : k => { node = module.service_vm[k].node, vm_id = module.service_vm[k].vm_id, lxc = false } },
    { for k, v in local.service_lxcs : k => { node = module.service_lxc[k].node, vm_id = module.service_lxc[k].vm_id, lxc = true } },
    { siem01 = { node = module.siem01.node, vm_id = module.siem01.vm_id, lxc = false } },
  )

  # Rule shorthand: [proto, ports, source (address, CIDR or +ipset), comment]
  ssh_ping = [
    ["tcp", "22", "+controller", "Ansible"],
    ["icmp", "", "+controller", "ping from the controller"],
  ]
  guest_rules = {
    edge01  = [["tcp", "443", "", "HTTPS (LAN, and the internet when exposed)"]]
    idp01   = [["tcp", "9000,9010", local.zp.unifi_edge, "Authentik and proxy outpost via Caddy"], ["tcp", "636", local.guest_ip.media01, "LDAPS for Jellyfin"]]
    git01   = [["tcp", "3000", local.zp.unifi_edge, "Forgejo via Caddy"], ["tcp", "2222", "+admins", "git over SSH"], ["tcp", "2222", local.guest_ip.sync01, "vault-git push"]]
    cloud01 = [["tcp", "8080", local.zp.unifi_edge, "Nextcloud via Caddy"], ["tcp", "9980", local.zp.unifi_edge, "Collabora via Caddy"]]
    pw01    = [["tcp", "8180", local.zp.unifi_edge, "Vaultwarden via Caddy"]]
    mdm01   = [["tcp", "8280", local.zp.unifi_edge, "Fleet via Caddy"]]
    hs01    = [["tcp", "8080", local.zp.unifi_edge, "Headscale via Caddy"]]
    ts01    = [["udp", "41641", "", "WireGuard from VPN devices (direct connections)"]]
    ts02    = [["udp", "41642", "", "WireGuard from VPN devices (direct connections)"]]
    mail01 = [
      ["tcp", "993,465,443", local.zp.unifi_lan, "IMAP, submission, account portal from the LAN"],
      ["tcp", "993,465,443", local.zp.unifi_ts, "same, from VPN devices (through ts01)"],
    ]
    pbs01 = [["tcp", "8007", "+admins", "PBS web UI"], ["tcp", "8007", "+nodes", "backups from the nodes"], ["tcp", "22", "+admins", "SSH (admins)"]]
    siem01 = [
      ["tcp", "443", "+admins", "Wazuh dashboard"], ["tcp", "22", "+admins", "SSH (admins)"],
      ["tcp", "1514:1515", "+agents", "Wazuh agents"], ["udp", "514", "__SEC_NET__.1", "UniFi syslog (CEF)"],
    ]
    media01 = [["tcp", "8096,4533,13378", local.zp.unifi_edge, "Jellyfin, Navidrome and Audiobookshelf via Caddy"]]
    sync01  = [["tcp", "8384", local.zp.unifi_edge, "Syncthing GUI via Caddy"], ["tcp", "22000", local.zp.unifi_lan, "Syncthing peers"], ["udp", "22000", local.zp.unifi_lan, "Syncthing peers (QUIC)"]]
    files01 = [["tcp", "445", local.zp.unifi_lan, "SMB"]]
    ai01    = [["tcp", "11434", "+controller", "Ollama API"]]
  }
}

check "every_guest_has_rules" {
  assert {
    condition     = length(setsubtract(keys(local.guests), keys(local.guest_rules))) == 0
    error_message = "Guests without firewall rules: ${join(", ", setsubtract(keys(local.guests), keys(local.guest_rules)))}. Add them to guest_rules."
  }
}

# ---------------------------------------------------------------- datacenter: on, but the nodes keep ACCEPT
# The nodes' own inbound filtering is a separate step (it can lock out the Proxmox UI and cluster traffic).
resource "proxmox_virtual_environment_cluster_firewall" "dc" {
  enabled       = true
  ebtables      = true
  input_policy  = "ACCEPT"
  output_policy = "ACCEPT"

  log_ratelimit {
    enabled = true
    burst   = 10
    rate    = "5/second"
  }
}

resource "proxmox_virtual_environment_firewall_ipset" "sets" {
  for_each = {
    controller = { comment = "Ansible / OpenTofu controllers (admin workstation, paw01)", cidrs = [local.zp.unifi_workstation, local.zp.unifi_paw] }
    admins     = { comment = "Admin workstations (admin workstation, paw01)", cidrs = [local.zp.unifi_workstation, local.zp.unifi_paw] }
    nodes      = { comment = "Proxmox nodes", cidrs = local.zp.unifi_nodes }
    agents     = { comment = "Lab networks with Wazuh agents (mgmt, services, edge)", cidrs = ["__MGMT_NET__.0/24", "__SVC_NET__.0/24", "__DMZ_NET__.0/24"] }
  }
  name    = each.key
  comment = "${each.value.comment} (managed by OpenTofu)"

  dynamic "cidr" {
    for_each = each.value.cidrs
    content {
      name = cidr.value
    }
  }
}

# Seen on every guest in audit mode (Oct 14-15), all from the gateways or between guests, none wanted:
locals {
  quiet_drop = [
    ["udp", "5353", "mDNS (gateway, IPv4 and IPv6)"],
    ["udp", "10001", "UniFi device discovery broadcast"],
    ["udp", "21027", "Syncthing local discovery broadcast"],
    ["igmp", "", "IGMP membership queries"],
  ]
}

# ---------------------------------------------------------------- per guest
resource "proxmox_virtual_environment_firewall_options" "guest" {
  for_each = local.guests

  node_name    = each.value.node
  vm_id        = each.value.lxc ? null : each.value.vm_id
  container_id = each.value.lxc ? each.value.vm_id : null

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
  for_each = local.guests

  node_name    = each.value.node
  vm_id        = each.value.lxc ? null : each.value.vm_id
  container_id = each.value.lxc ? each.value.vm_id : null

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

  # Multicast and broadcast chatter no guest needs: dropped without a log line in both modes, so the
  # firewall log (and Wazuh 100421/100422) only shows traffic someone actually aimed at a guest.
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

  # Audit mode: accept the rest, logged, so the log shows exactly what enforcing would break
  dynamic "rule" {
    for_each = var.firewall_enforce ? [] : [1]
    content {
      type    = "in"
      action  = "ACCEPT"
      log     = "info"
      comment = "would-drop (audit mode, firewall_enforce = false)"
    }
  }

  depends_on = [
    proxmox_virtual_environment_firewall_ipset.sets,
    proxmox_virtual_environment_cluster_firewall.dc,
  ]
}
