# The public addresses, for the DNS records the runbook lists (A, AAAA, SPF) and for checking the PTR.
output "mail_ipv4" {
  value = hcloud_server.mail01.ipv4_address
}

output "mail_ipv6" {
  value = hcloud_server.mail01.ipv6_address
}

output "mail_hostname" {
  value = local.hostname
}
