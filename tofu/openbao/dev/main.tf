locals {
  ca_root = "${path.module}/../../../ansible/files/dev/ca01-root.pem" # written by bin/ca-init
}

module "openbao" {
  source = "../../modules/openbao_config"

  ca_root_pem = fileexists(local.ca_root) ? file(local.ca_root) : null

  env = "dev"
  # paw01's leg on the dev network (inventories/dev lab_controllers)
  controller_cidrs = ["__DEV_NET__.2/32"]
}

output "approle_role_ids" {
  value = module.openbao.approle_role_ids
}
