# mail01-vps: a Hetzner VPS for domain email (docs/howto/mail-public-edge.md). It exists because the residential ISP blocks
# outbound port 25 at home, so the lab can never deliver mail directly; this box can.
#
# Management (SSH, the Stalwart admin UI) is reachable only over the tailnet once it has joined, never from
# the public internet. Only the mail ports and ACME are open to the world. cloud-init creates the ansible
# account and installs Tailscale; the operator joins it to Headscale by hand (the runbook), then
# playbooks/mail.yml configures Stalwart.

locals {
  hostname = "mail.${var.base_domain}"
  # The recovery-kit key, same as every lab guest (committed, public)
  ansible_pubkey = trimspace(file("${path.module}/../../../ansible/files/pubkeys/ansible.pub"))
}

resource "hcloud_ssh_key" "ansible" {
  name       = "labstack-ansible"
  public_key = local.ansible_pubkey
}

resource "hcloud_server" "mail01" {
  name        = "mail01-vps"
  server_type = var.server_type
  image       = "debian-13"
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.ansible.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  # Create the ansible account with the same key, lock down SSH, install Tailscale. The tailnet join is a
  # manual step (needs a pre-auth key from hs01): docs/howto/mail-public-edge.md.
  user_data = <<-EOT
    #cloud-config
    users:
      - name: ansible
        groups: [sudo]
        shell: /bin/bash
        sudo: ["ALL=(ALL) NOPASSWD:ALL"]
        ssh_authorized_keys:
          - ${local.ansible_pubkey}
    package_update: true
    packages: [curl]
    runcmd:
      - ['sh', '-c', 'curl -fsSL https://tailscale.com/install.sh | sh']
      # Join the tailnet on first boot, so management never needs public SSH. --accept-dns=false: this box
      # runs its own resolver and must not take the lab's split DNS. No routes/exit: it is a leaf node.
      - ['sh', '-c', '${var.tailscale_authkey != "" ? "tailscale up --login-server=https://hs.${var.base_domain} --authkey=${var.tailscale_authkey} --hostname=mail01-vps --accept-dns=false --accept-routes=false" : "echo no authkey set; join by hand per the runbook"}']
    write_files:
      - path: /etc/ssh/sshd_config.d/90-labstack.conf
        content: |
          PasswordAuthentication no
          PermitRootLogin prohibit-password
  EOT

  labels = {
    env  = "prod"
    role = "mail"
  }

  lifecycle {
    # The disk holds the mailboxes; never let a type or image change rebuild it
    prevent_destroy = true
    ignore_changes  = [user_data, image, ssh_keys]
  }
}

# Reverse DNS must match the HELO hostname, or receivers reject or spam-bin the mail.
resource "hcloud_rdns" "mail01_v4" {
  server_id  = hcloud_server.mail01.id
  ip_address = hcloud_server.mail01.ipv4_address
  dns_ptr    = local.hostname
}

resource "hcloud_rdns" "mail01_v6" {
  server_id  = hcloud_server.mail01.id
  ip_address = hcloud_server.mail01.ipv6_address
  dns_ptr    = local.hostname
}

# Public firewall: mail ports and ACME only. Management rides the tailnet (WireGuard arrives as normal UDP,
# so no inbound TCP rule is needed for it), so SSH and the admin UI are never exposed here.
resource "hcloud_firewall" "mail01" {
  name = "mail01-public"

  dynamic "rule" {
    for_each = toset(["25", "465", "587", "143", "993", "443"])
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = rule.value
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  }

  # Tailscale's own UDP, so devices can make a direct tunnel instead of falling back to a relay
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "41641"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # ICMP (path MTU, ping)
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "mail01" {
  firewall_id = hcloud_firewall.mail01.id
  server_ids  = [hcloud_server.mail01.id]
}
