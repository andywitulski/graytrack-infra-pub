# Service containers. Bind mounts, ID maps and GPU devices are added by Ansible (pve_lxc_host).
locals {
  # Find the current name on a node: pveam update && pveam available --section system | grep debian-13
  lxc_template_file = "debian-13-standard_13.6-1_amd64.tar.zst"
  lxc_template_url  = "http://download.proxmox.com/images/system/${local.lxc_template_file}"
  lxc_template_node = ["pve02", "pve03"]

  service_lxcs = {
    media01 = { node = "pve03", vm_id = 4201, cores = 2, mem = 3072, disk = 32, ip = "__SVC_NET__.20/24", pool = "data", nesting = true, desc = "Jellyfin, Navidrome and Audiobookshelf." }
    sync01  = { node = "pve03", vm_id = 4211, cores = 1, mem = 1024, disk = 8, ip = "__SVC_NET__.21/24", pool = "data", nesting = true, desc = "Syncthing." }
    files01 = { node = "pve03", vm_id = 4221, cores = 1, mem = 1024, disk = 8, ip = "__SVC_NET__.22/24", pool = "data", nesting = true, desc = "Samba file shares." }
    hs01    = { node = "pve03", vm_id = 4231, cores = 1, mem = 512, disk = 8, ip = "__SVC_NET__.23/24", pool = "services", nesting = true, desc = "Headscale: VPN coordination server." }
    ts01    = { node = "pve03", vm_id = 4241, cores = 1, mem = 512, disk = 8, ip = "__SVC_NET__.24/24", pool = "services", nesting = true, desc = "Tailscale subnet router: VPN entry into the lab." }
    ts02    = { node = "pve03", vm_id = 4251, cores = 1, mem = 512, disk = 8, ip = "__SVC_NET__.25/24", pool = "services", nesting = true, desc = "Tailscale exit node: full tunnel for the roaming device." }
    mail01  = { node = "pve03", vm_id = 4261, cores = 2, mem = 2048, disk = 64, ip = "__SVC_NET__.26/24", pool = "data", nesting = false, desc = "Mail: Stalwart mailboxes, Gmail and Proton sync (mbsync, Proton Bridge)." }
    ai01    = { node = "pve02", vm_id = 4141, cores = 6, mem = 12288, disk = 200, ip = "__SVC_NET__.14/24", pool = "services", nesting = true, desc = "Ollama (local LLM)." }
  }
}

resource "proxmox_download_file" "debian13_lxc" {
  for_each     = toset(local.lxc_template_node)
  node_name    = each.key
  datastore_id = "local"
  content_type = "vztmpl"
  url          = local.lxc_template_url
  file_name    = local.lxc_template_file
  overwrite    = false
}

module "service_lxc" {
  source   = "../../modules/service_lxc"
  for_each = local.service_lxcs

  name             = each.key
  description      = each.value.desc
  node             = each.value.node
  vm_id            = each.value.vm_id
  env_tag          = "env-prod"
  template_file_id = proxmox_download_file.debian13_lxc[each.value.node].id
  cores            = each.value.cores
  memory_mb        = each.value.mem
  disk_gb          = each.value.disk
  nesting          = each.value.nesting
  service_vlan     = 120
  native_vlan      = local.native_vlan
  service_ipv4     = each.value.ip
  service_gateway  = local.svc_gw
  dns_servers      = local.svc_dns
  ansible_pubkey   = local.ansible_pubkey
  firewall         = true
  pool_id          = each.value.pool == "services" ? proxmox_virtual_environment_pool.services.pool_id : proxmox_virtual_environment_pool.data.pool_id
}
