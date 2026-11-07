# Service containers (mirrors tofu/envs/prod/lxc.tf; no ai01 in dev).
# Bind mounts and ID maps are added by Ansible (pve_lxc_host) from inventories/common.
locals {
  lxc_template_file = "debian-13-standard_13.6-1_amd64.tar.zst"
  lxc_template_url  = "http://download.proxmox.com/images/system/${local.lxc_template_file}"
  lxc_template_node = ["pvedev3"]

  service_lxcs = {
    media01 = { node = "pvedev3", vm_id = 1201, cores = 2, mem = 1024, disk = 8, ip = "__DEV_NET__.50/24", desc = "Jellyfin, Navidrome and Audiobookshelf, dev." }
    sync01  = { node = "pvedev3", vm_id = 1211, cores = 1, mem = 512, disk = 4, ip = "__DEV_NET__.51/24", desc = "Syncthing, dev." }
    files01 = { node = "pvedev3", vm_id = 1221, cores = 1, mem = 512, disk = 4, ip = "__DEV_NET__.52/24", desc = "Samba file shares, dev." }
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
  env_tag          = "env-dev"
  template_file_id = proxmox_download_file.debian13_lxc[each.value.node].id
  cores            = each.value.cores
  memory_mb        = each.value.mem
  disk_gb          = each.value.disk
  nesting          = true
  service_ipv4     = each.value.ip
  service_gateway  = local.svc_gw
  dns_servers      = local.svc_dns
  ansible_pubkey   = local.ansible_pubkey
  pool_id          = proxmox_virtual_environment_pool.data.pool_id
}
