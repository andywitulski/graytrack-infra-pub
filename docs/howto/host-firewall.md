# Roll out host firewalls

**Goal:** Give every service guest an inbound allow list enforced on the hypervisor, moving safely from audit to enforcement.

**Why:** [ADR-0007](../adr/0007-zone-segmentation-and-guest-firewalls.md). **Accept with:** [ATP-004](../atp/ATP-004-segmentation.md).

Rules live in `tofu/envs/prod/firewall.tf`. Addresses come from `ansible/network/zone_policy.yml`. Outbound stays with the zone policy. Nodes keep input ACCEPT for now, because a mistake there locks out the UI and cluster traffic.

## 1. Deploy in audit mode

`firewall_enforce = false` is the default. Turning on the NIC flag re-plugs each guest's NIC, costing a few seconds of network per guest.

```bash
bin/tf prod plan
```
```bash
bin/tf prod apply
```

## 2. Observe

Guests accept everything, but anything no rule covers is logged, and node agents ship it to Wazuh. Treat each rule **100421** ("has no rule") as either a missing rule, which you add to `guest_rules`, or traffic that should not exist, which you leave.

Multicast and broadcast chatter (mDNS, discovery, IGMP) is dropped without logging by `quiet_drop`. In the first day of the original rollout this accounted for every event.

Run through a few days of normal use, including sync clients, backups, a playbook run and media playback, until 100421 stays quiet.

## 3. Enforce

Set the default to `true` in `firewall.tf` and commit.

```bash
bin/tf prod apply -var firewall_enforce=true
```

Drops are now rule **100422**. Twenty from one source in a minute is **100423**, level 10.

## Recover from a lockout

The node's own UI and SSH are not affected. On the node, use one of these, then fix the rule in code and apply:

- LXC: `pct set <id> -net0 ...,firewall=0`
- VM: Hardware, Network Device, uncheck Firewall
- Everything: Datacenter, Firewall, Options, Firewall: No
