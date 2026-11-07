# Platform tier: the stateful control plane every other root and playbook depends on.
#   pg01   PostgreSQL. OpenTofu state for every root under tofu/ (one schema each), and OpenBao's storage.
#   bao01  OpenBao. Secrets for services and automation, with an audit log shipped to the SIEM.
#   ca01   step-ca. X.509 and SSH certificate authority (root offline in sops), database on pg01.
#
# Kept out of tofu/envs/prod on purpose: a bad plan there cannot destroy the database its own state lives
# in, and this root is small enough to rebuild or re-import by hand. Both guests carry the Proxmox
# protection flag, so even a destroy from here fails until the flag is cleared.
#
# Placement: pve02, not the NAS node. The NAS holds their backups (PBS nightly, and the pg_dump files
# inside pg01 travel with it), so losing one box never takes the data and its backups together.
#
# Order on a fresh build (docs/howto/platform-tier.md):
#   bin/tf-platform prod bootstrap   guests, local state
#   bin/ap prod playbooks/platform.yml --limit platform_guests -e ansible_user=root   first run creates the ansible account
#   bin/ap prod playbooks/platform.yml
#   bin/tf-platform prod migrate     state into pg01
#   bin/bao-init prod                initialize OpenBao, keys into sops
#   bin/ca-init prod                 create the CA keys (root stays off the lab), then platform.yml again
locals {
  ansible_pubkey = trimspace(file("${path.module}/../../../ansible/files/pubkeys/ansible.pub"))
  mgmt_gw        = "__MGMT_NET__.1"
  native_vlan    = 100 # mgmt is untagged on the node trunks: guests on it leave service_vlan null

  # The Debian 13 template tofu/envs/prod/lxc.tf downloads on pve02 and pve03. Referenced by ID
  # rather than downloaded again: two roots managing one file would fight over it.
  lxc_template_id = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"

  # pve_vmid in ansible/inventories/prod/hosts.yml and the addresses in ansible/network/zone_policy.yml
  # and tofu/platform/prod/client.env must match these.
  platform_lxcs = {
    pg01  = { node = "pve02", vm_id = 4301, cores = 2, mem = 2048, disk = 16, ip = "__MGMT_NET__.22/24", desc = "PostgreSQL: OpenTofu state and OpenBao storage." }
    bao01 = { node = "pve02", vm_id = 4311, cores = 1, mem = 1024, disk = 8, ip = "__MGMT_NET__.23/24", desc = "OpenBao secrets manager." }
    ca01  = { node = "pve02", vm_id = 4321, cores = 1, mem = 1024, disk = 8, ip = "__MGMT_NET__.24/24", desc = "step-ca: X.509 and SSH certificate authority." }
  }
}

resource "proxmox_virtual_environment_pool" "platform" {
  pool_id = "platform"
  comment = "State backend and secrets manager (managed by OpenTofu, tofu/platform/prod)"
}

module "platform_lxc" {
  source   = "../../modules/service_lxc"
  for_each = local.platform_lxcs

  name             = each.key
  description      = each.value.desc
  node             = each.value.node
  vm_id            = each.value.vm_id
  env_tag          = "env-prod"
  tags             = ["platform"]
  template_file_id = local.lxc_template_id
  cores            = each.value.cores
  memory_mb        = each.value.mem
  disk_gb          = each.value.disk
  nesting          = true # systemd sandboxing in the guests (OpenBao's unit uses ProtectSystem, PrivateTmp)
  service_vlan     = null
  native_vlan      = local.native_vlan
  service_ipv4     = each.value.ip
  service_gateway  = local.mgmt_gw
  dns_servers      = [local.mgmt_gw]
  ansible_pubkey   = local.ansible_pubkey
  firewall         = true
  protection       = true
  pool_id          = proxmox_virtual_environment_pool.platform.pool_id
}
