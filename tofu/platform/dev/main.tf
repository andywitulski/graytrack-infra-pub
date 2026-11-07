# Platform tier, dev (mirrors tofu/platform/prod on the nested cluster: flat network, no guest firewall,
# guest IDs are prod's minus 3000). See the prod root for what each guest is for and the build order.
# No protection flag in dev: the nested cluster is rebuilt often and destroy must stay one command.
locals {
  ansible_pubkey = trimspace(file("${path.module}/../../../ansible/files/pubkeys/ansible.pub"))
  svc_gw         = "__DEV_NET__.1"
  svc_dns        = ["__DEV_NET__.1"] # dnsmasq on the labnode node (roles/lab_node)

  # Downloaded by tofu/envs/dev/lxc.tf on pvedev3
  lxc_template_id = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"

  platform_lxcs = {
    pg01  = { node = "pvedev3", vm_id = 1301, cores = 1, mem = 1024, disk = 8, ip = "__DEV_NET__.60/24", desc = "PostgreSQL: OpenTofu state and OpenBao storage, dev." }
    bao01 = { node = "pvedev3", vm_id = 1311, cores = 1, mem = 512, disk = 4, ip = "__DEV_NET__.61/24", desc = "OpenBao secrets manager, dev." }
    ca01  = { node = "pvedev3", vm_id = 1321, cores = 1, mem = 512, disk = 4, ip = "__DEV_NET__.62/24", desc = "step-ca certificate authority, dev." }
  }
}

resource "proxmox_virtual_environment_pool" "platform" {
  pool_id = "platform"
  comment = "State backend and secrets manager (managed by OpenTofu, tofu/platform/dev)"
}

module "platform_lxc" {
  source   = "../../modules/service_lxc"
  for_each = local.platform_lxcs

  name             = each.key
  description      = each.value.desc
  node             = each.value.node
  vm_id            = each.value.vm_id
  env_tag          = "env-dev"
  tags             = ["platform"]
  template_file_id = local.lxc_template_id
  cores            = each.value.cores
  memory_mb        = each.value.mem
  disk_gb          = each.value.disk
  nesting          = true
  service_ipv4     = each.value.ip
  service_gateway  = local.svc_gw
  dns_servers      = local.svc_dns
  ansible_pubkey   = local.ansible_pubkey
  pool_id          = proxmox_virtual_environment_pool.platform.pool_id
}
