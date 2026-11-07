# Build the lab node

**Goal:** Build `labnode`, a standalone Proxmox host with the admin workstation (`paw01`), GPU guest (`gpu01`), security testing VM (`kali01`), and nested dev cluster.

**Why:** [ADR-0005](../adr/0005-lab-node-and-paw.md).

| Host | VMID | Address | Job |
|---|---|---|---|
| `labnode` | | `__MGMT_NET__.4`; gateway of `__DEV_NET__.1` | Proxmox; NAT and DNS for dev |
| `paw01` | 5001 | `__MGMT_NET__.30`, `__DEV_NET__.2`, `__TB_NET__.2/30` | Second controller |
| `gpu01` | 5011 | `__SVC_NET__.15` | Ollama on a passed-through GPU, `rag` database |
| `kali01` | 5021 | DHCP on `__KALI_NET__.0/24` | Internet only, installed by hand |
| `pvedev1`-`3` | 5101-5103 | `__DEV_NET__.11`-`13` | Nested cluster |

The node uses prod's platform tier: state in `pg01`, certificates from `ca01`. `bin/ap labnode` and `bin/tf labnode` ask for confirmation like prod.

## 1. Network

Add the node's port to `ansible/network/switching.yml` with profile `Node trunk`. Do this together with the firewall step: the native VLAN becomes Management, so a LAN address stops working the moment it applies. Check that nothing else uses the `.4` and `.30` addresses.

```bash
bin/ap prod playbooks/unifi_switching.yml --check --diff
```
```bash
bin/ap prod playbooks/unifi_firewall.yml --check --diff
```
```bash
bin/ap prod playbooks/unifi_switching.yml && bin/ap prod playbooks/unifi_firewall.yml
```
```bash
bin/ap prod playbooks/unifi_dns.yml
```

## 2. Node address and facts

From the node's console (not SSH), set `address` and `gateway` in `/etc/network/interfaces`, update `/etc/hosts`, and run `ifreload -a`. Then collect the NIC address and disk ID for `inventories/labnode/host_vars/labnode.yml`:

```bash
ip -br link
```
```bash
ls -l /dev/disk/by-id/ | grep nvme
```
```bash
lspci -nn -d 10de:
```

## 3. Configure the node

Create `secrets/labnode.enc.env` first, because `bin/ap labnode` decrypts it on every run. It holds `PROXMOX_VE_ENDPOINT` and `TF_VAR_state_passphrase`. Copy the bootstrap key to root.

```bash
bin/ap labnode playbooks/bootstrap.yml -e ansible_user=root
```
```bash
bin/ap labnode playbooks/network.yml
```

Run `ifreload -a` from the console, then:

```bash
bin/ap labnode playbooks/labnode.yml --limit labnode
```
```bash
ssh ansible@labnode sudo reboot
```
```bash
bin/ap labnode playbooks/labnode.yml --limit labnode
```
```bash
ssh ansible@labnode 'lspci -nnk -d 10de: | grep driver'
```
```bash
bin/ap labnode playbooks/ssh-ca.yml --limit labnode
```

Every GPU function must show `vfio-pci`. Laptop GPUs can hide their VBIOS; if `nvidia-smi` later fails with `RmInitAdapter failed`, try a ROM file. The fallback is an LXC with the host driver.

The lab pool claims its disk only if blank. Check with `wipefs -n`.

**Local admin stays PAM plus TOTP.** No SSO realm on this node.

## 4. OpenTofu

Trust the node's CA and create the API token. The token goes straight into sops, never to the screen.

```bash
V=$(ssh ansible@labnode sudo pveum user token add tofu@pve tofu --privsep 0 --output-format json | jq -r .value)
sops set secrets/labnode.enc.env '["PROXMOX_VE_API_TOKEN"]' "\"tofu@pve"'!'"tofu=$V\""; unset V
```
```bash
bin/tf labnode init && bin/tf labnode plan && bin/tf labnode apply
```

## 5. Guests and second controller

```bash
bin/ap labnode playbooks/labnode.yml --limit service_guests
```

On `paw01`, restore by hand from the offline copy: the age key (0600) and SSH keys. Automation never places these. Management allows HTTPS out, not SSH, so clone over HTTPS or SSH on port 443. Then prove it from `paw01`:

```bash
bin/tf prod plan
```
```bash
bin/ap prod playbooks/services.yml --check --limit siem01
```
```bash
bin/ssh-cert prod status
```

## 6. Dev cluster

Runs on `paw01`, the only machine on the dev network. While dev exists, every `bin/tf labnode` run needs `-var build_dev=true`: **without it, the plan destroys `pvedev1`-`3`.**

```bash
PVEDEV_ROOT_PW_HASH=$(openssl passwd -6) bin/ap labnode playbooks/labnode-dev-isos.yml
```
```bash
bin/tf labnode apply -var build_dev=true
```

Continue with [Build the dev environment](dev-environment.md).

## 7. Secrets, policies, node services

Run `paw01` before the next step. It installs a cloud-init drop-in that keeps host keys when NICs change; otherwise the host certificate stops matching.

```bash
bin/gen-service-secrets labnode
```
```bash
bin/ap prod playbooks/unifi_firewall.yml
```
```bash
bin/ap labnode playbooks/labnode.yml --limit labnode
```
```bash
bin/ap labnode playbooks/labnode.yml --limit paw01
```

## 8. Added disks and networks

Expect a GPU models disk, the isolated network and the point-to-point NIC, with nothing replaced.

```bash
bin/tf labnode plan && bin/tf labnode apply
```
```bash
ssh ansible@paw01 'ip -br a; sudo cloud-init status'
```

## 9. GPU guest

Fill `ollama_models`, then:

```bash
bin/ap labnode playbooks/labnode.yml --limit gpu01
```

The `rag` database holds embeddings, which are rebuilt by re-ingesting sources, so a restore is optional. Connect over TLS with `sslmode=verify-full`. To restore a dump, exclude its `EXTENSION` entries (the superuser already created `vector`) and restore with `--no-owner --no-privileges --role=rag`.

## 10. Agents and backups

Agents should show Active:

```bash
ssh ansible@siem01 sudo /var/ossec/bin/agent_control -l
```

The node backs up nightly at 02:30 with its own token and key. PBS encrypts on the node before sending, which matters because `paw01`'s backup contains the age key.

```bash
bin/ap prod playbooks/backups.yml --limit pbs01
```
```bash
ssh ansible@pbs01 sudo cat /root/pbs-labnode-token.json | sed -n 's/.*"value": *"\([^"]*\)".*/\1/p' | bin/bao-secret labnode set pbs_cluster_token_secret
```
```bash
ssh ansible@pbs01 sudo rm /root/pbs-labnode-token.json
```
```bash
bin/ap labnode playbooks/backups.yml
```

[Save the new key](backups-pbs.md#save-the-encryption-key-the-same-day) with the `labnode` paths. Prove it by restoring `paw01` to a spare VMID **with NICs disconnected**, since a second `paw01` on the network would clash.

## 11. Security testing VM

Verify the release's signed checksum list before trusting a checksum from it. Put the hash in `tofu/envs/labnode/kali.tf`, set `kali_build = true`, and apply. Install from the console, then eject the ISO.

```bash
curl -fsSLO "https://cdimage.kali.org/kali-<release>/SHA256SUMS" -O "https://cdimage.kali.org/kali-<release>/SHA256SUMS.gpg"
```
```bash
gpg --verify SHA256SUMS.gpg SHA256SUMS
```

Check isolation from inside: [ATP-004](../atp/ATP-004-segmentation.md). Drops are logged on the node, and its agent ships them. It starts by hand (`on_boot = false`).

## 12. Point-to-point admin link

An independent path from the workstation to `paw01`, working with the switch, gateway or Management VLAN down. The node only bridges the cable. Neither end has a gateway on it, so nothing routes through.

Configure the workstation's Thunderbolt interface as `__TB_NET__.1/30` with no router, then:

```sshconfig
Host paw01-tb
  HostName __TB_NET__.2
  HostKeyAlias paw01.example.com
  User labadmin
  IdentityFile ~/.ssh/id_ed25519_paw
```

`HostKeyAlias` checks the same host certificate, so no new host key is trusted.
