locals {
  ansible_pubkey = trimspace(file("${path.module}/../../../ansible/files/pubkeys/ansible.pub"))
  svc_gw         = "__SVC_NET__.1"
  svc_dns        = ["__SVC_NET__.1"] # UniFi gateway on the services VLAN
  native_vlan    = 100               # mgmt: untagged on the node trunks, so guests on it use vlan = null

  service_vms = {
    edge01  = { node = "pve01", vm_id = 4101, cores = 1, mem = 1024, disk = 16, vlan = 125, ip = "__DMZ_NET__.10/24", gw = "__DMZ_NET__.1", storage_ip = null, desc = "Edge reverse proxy (Caddy)." }
    idp01   = { node = "pve01", vm_id = 4111, cores = 2, mem = 4096, disk = 32, vlan = 120, ip = "__SVC_NET__.11/24", gw = "__SVC_NET__.1", storage_ip = null, desc = "Identity provider (Authentik)." }
    git01   = { node = "pve01", vm_id = 4121, cores = 2, mem = 3072, disk = 64, vlan = 120, ip = "__SVC_NET__.12/24", gw = "__SVC_NET__.1", storage_ip = null, desc = "Git forge (Forgejo)." }
    cloud01 = { node = "pve02", vm_id = 4131, cores = 4, mem = 8192, disk = 64, vlan = 120, ip = "__SVC_NET__.13/24", gw = "__SVC_NET__.1", storage_ip = "__STOR_NET__.13/24", desc = "Nextcloud and Collabora." }
    pw01    = { node = "pve01", vm_id = 4161, cores = 1, mem = 1536, disk = 16, vlan = 120, ip = "__SVC_NET__.16/24", gw = "__SVC_NET__.1", storage_ip = null, desc = "Password manager (Vaultwarden)." }
    mdm01   = { node = "pve01", vm_id = 4171, cores = 2, mem = 3072, disk = 32, vlan = 120, ip = "__SVC_NET__.17/24", gw = "__SVC_NET__.1", storage_ip = null, desc = "Device management (Fleet MDM)." }
    pbs01   = { node = "pve02", vm_id = 4151, cores = 2, mem = 4096, disk = 32, vlan = null, ip = "__MGMT_NET__.21/24", gw = "__MGMT_NET__.1", storage_ip = "__STOR_NET__.21/24", desc = "Proxmox Backup Server (datastore on the NAS via NFS)." }
  }
}

module "service_vm" {
  source   = "../../modules/service_vm"
  for_each = local.service_vms

  name                = each.key
  description         = each.value.desc
  node                = each.value.node
  pool_id             = proxmox_virtual_environment_pool.services.pool_id
  vm_id               = each.value.vm_id
  env_tag             = "env-prod"
  cores               = each.value.cores
  memory_mb           = each.value.mem
  disk_gb             = each.value.disk
  image_file_id       = proxmox_download_file.debian13[each.value.node].id
  vendor_data_file_id = proxmox_virtual_environment_file.vendor_data[each.value.node].id
  service_vlan        = each.value.vlan
  native_vlan         = local.native_vlan
  service_ipv4        = each.value.ip
  service_gateway     = each.value.gw
  storage_bridge      = each.value.storage_ip == null ? null : "vmbr1"
  storage_ipv4        = each.value.storage_ip
  dns_servers         = [each.value.gw]
  ansible_pubkey      = local.ansible_pubkey
  firewall            = true
  vtpm                = true # ADR-0006; apply one VM at a time (stop/start)
}
