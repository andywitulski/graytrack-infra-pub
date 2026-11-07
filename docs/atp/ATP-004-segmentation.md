# ATP-004: Network segmentation

**Objective:** Prove zones and guest firewalls block what they should.
**Prerequisites:** Zone policy applied; guest firewalls deployed. Use `nc -vz -w3 <host> <port>`.

| ID | Test | From | To | Expected | Tag |
|---|---|---|---|---|---|
| T1 | DMZ reaches only its backends | `edge01` | `idp01:9000` | Connected | |
| T2 | DMZ cannot pivot | `edge01` | `idp01:22`, a LAN host `:22`, `pve01:8006` | Timed out; rule 100308 | |
| T3 | Same-VLAN filtering | `media01` | `git01:22` | **After enforce:** blocked, rule 100422. **Now:** connects, logged as 100421 | `after-enforce` |
| T4 | Non-admin cannot reach management | A LAN client that is not a controller | `pve01:8006`, `pg01:5432`, `bao01:8200` | Timed out | |
| T5 | Guest cannot disable its filter | Root in a guest flushes its own iptables, then test T3 | Filter unchanged, since it is enforced on the node | `after-enforce` |
| T6 | Isolated network is isolated | `kali01` | `curl -sI https://kali.org`; `getent hosts labnode.example.com`; `ping __MGMT_NET__.1`; `nc -vz __KALI_NET__.1 22` | HTTPS works; names withheld; ping and SSH blocked; drops logged by `labnode` | |
| T7 | Port scan from outside | External host: scan the WAN address | Only TCP 443 and the two VPN UDP ports respond | |

**Sample evidence:** [edge isolation](../evidence/sample-edge-dmz-isolation.txt).
