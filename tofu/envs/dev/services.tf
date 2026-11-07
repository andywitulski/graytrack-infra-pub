locals {
  ansible_pubkey = trimspace(file("${path.module}/../../../ansible/files/pubkeys/ansible.pub"))
  svc_gw         = "__DEV_NET__.1"
  svc_dns        = ["__DEV_NET__.1"] # dnsmasq on the labnode node (also answers the *.dev.example.com service names)

  # Mirrors tofu/envs/prod/services.tf + siem.tf on a flat network, scaled down.
  # Placement follows prod: pvedev1 ~ pve01, pvedev2 ~ pve02. Guest IDs are prod's minus 3000.
  service_vms = {
    siem01  = { node = "pvedev1", vm_id = 1001, cores = 2, mem = 6144, disk = 50, pool = "security", storage_ip = null, ip = "__DEV_NET__.40/24", desc = "Wazuh SIEM (manager, indexer, dashboard), dev." }
    edge01  = { node = "pvedev1", vm_id = 1101, cores = 1, mem = 1024, disk = 12, pool = "services", storage_ip = null, ip = "__DEV_NET__.41/24", desc = "Edge reverse proxy (Caddy), dev." }
    idp01   = { node = "pvedev1", vm_id = 1111, cores = 2, mem = 2048, disk = 16, pool = "services", storage_ip = null, ip = "__DEV_NET__.42/24", desc = "Identity provider (Authentik), dev." }
    git01   = { node = "pvedev1", vm_id = 1121, cores = 1, mem = 1536, disk = 16, pool = "services", storage_ip = null, ip = "__DEV_NET__.43/24", desc = "Git forge (Forgejo), dev." }
    cloud01 = { node = "pvedev2", vm_id = 1131, cores = 2, mem = 2048, disk = 16, pool = "services", storage_ip = "__DEV_STOR_NET__.44/24", ip = "__DEV_NET__.44/24", desc = "Nextcloud, dev." }
    pbs01   = { node = "pvedev2", vm_id = 1151, cores = 2, mem = 2048, disk = 16, pool = "services", storage_ip = "__DEV_STOR_NET__.46/24", ip = "__DEV_NET__.46/24", desc = "Proxmox Backup Server (datastore on pvedev3 via NFS), dev." }
  }
}

module "service_vm" {
  source   = "../../modules/service_vm"
  for_each = local.service_vms

  name                = each.key
  description         = each.value.desc
  node                = each.value.node
  pool_id             = each.value.pool == "security" ? proxmox_virtual_environment_pool.security.pool_id : proxmox_virtual_environment_pool.services.pool_id
  vm_id               = each.value.vm_id
  env_tag             = "env-dev"
  tags                = each.value.pool == "security" ? ["security"] : []
  cores               = each.value.cores
  memory_mb           = each.value.mem
  disk_gb             = each.value.disk
  image_file_id       = proxmox_download_file.debian13[each.value.node].id
  vendor_data_file_id = proxmox_virtual_environment_file.vendor_data[each.value.node].id
  service_ipv4        = each.value.ip
  service_gateway     = local.svc_gw
  storage_bridge      = each.value.storage_ip == null ? null : "vmbr1"
  storage_ipv4        = each.value.storage_ip
  dns_servers         = local.svc_dns
  ansible_pubkey      = local.ansible_pubkey
  vtpm                = true # mirrors prod (ADR-0006)
}
