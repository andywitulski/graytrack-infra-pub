# Networks inside labnode (paw01 and gpu01 are on the prod VLANs). The node is the gateway of pvedev and
# kalinet and NATs them out its Management address, so nothing here needs a UniFi network.
#   pvedev    __DEV_NET__.0/24   the nested dev cluster, same addresses as under libvirt; paw01 (.2)
#   pvedevst  isolated L2    dev's storage network (__DEV_STOR_NET__.0/24, addressed by the dev nodes only)
#   kalinet   __KALI_NET__.0/24   kali01, internet only: the node drops everything from it to private ranges and
#                            to itself except DNS and DHCP (roles/lab_node, table inet labstack_kali)
# The Thunderbolt bridge for the Workstation to paw01 link (vmbrtb) is not SDN: roles/lab_node writes it.
# Dev's DNS stays at __DEV_NET__.1: dnsmasq on the node, configured by playbooks/labnode.yml.

resource "proxmox_sdn_zone_simple" "labnode" {
  id    = "labnode"
  nodes = [local.node]
}

resource "proxmox_sdn_vnet" "pvedev" {
  id    = "pvedev"
  zone  = proxmox_sdn_zone_simple.labnode.id
  alias = "dev cluster"
}

resource "proxmox_sdn_subnet" "pvedev" {
  vnet    = proxmox_sdn_vnet.pvedev.id
  cidr    = "__DEV_NET__.0/24"
  gateway = "__DEV_NET__.1"
  snat    = true
}

resource "proxmox_sdn_vnet" "pvedevst" {
  id    = "pvedevst"
  zone  = proxmox_sdn_zone_simple.labnode.id
  alias = "dev storage (isolated)"
}

resource "proxmox_sdn_vnet" "kalinet" {
  id    = "kalinet"
  zone  = proxmox_sdn_zone_simple.labnode.id
  alias = "kali (internet only)"
}

# No SDN DHCP: dnsmasq on the node serves kalinet (labstack-kalinet-dns), with the lab's names withheld
resource "proxmox_sdn_subnet" "kalinet" {
  vnet    = proxmox_sdn_vnet.kalinet.id
  cidr    = "__KALI_NET__.0/24"
  gateway = "__KALI_NET__.1"
  snat    = true
}

# The applier runs SDN Apply only when it is created, so it is replaced whenever an SDN object changes;
# otherwise a new vnet stays pending and a VM on it fails to start ("bridge ... does not exist").
resource "proxmox_sdn_applier" "labnode" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_simple.labnode,
      proxmox_sdn_vnet.pvedev,
      proxmox_sdn_subnet.pvedev,
      proxmox_sdn_vnet.pvedevst,
      proxmox_sdn_vnet.kalinet,
      proxmox_sdn_subnet.kalinet,
    ]
  }

  depends_on = [
    proxmox_sdn_subnet.pvedev,
    proxmox_sdn_vnet.pvedevst,
    proxmox_sdn_subnet.kalinet,
  ]
}
