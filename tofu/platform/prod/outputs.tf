output "platform_addresses" {
  description = "Service address of each platform guest."
  value       = { for k, m in module.platform_lxc : k => split("/", m.service_ipv4)[0] }
}
