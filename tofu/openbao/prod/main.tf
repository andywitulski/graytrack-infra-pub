locals {
  ca_root = "${path.module}/../../../ansible/files/prod/ca01-root.pem" # written by bin/ca-init
  # The controllers (admin workstation, paw01) from the zone policy, the one place their addresses are written
  zp = yamldecode(file("${path.module}/../../../ansible/network/zone_policy.yml"))
}

module "openbao" {
  source = "../../modules/openbao_config"

  ca_root_pem = fileexists(local.ca_root) ? file(local.ca_root) : null

  env              = "prod"
  controller_cidrs = ["${local.zp.unifi_workstation}/32", "${local.zp.unifi_paw}/32"]
}

output "approle_role_ids" {
  value = module.openbao.approle_role_ids
}
