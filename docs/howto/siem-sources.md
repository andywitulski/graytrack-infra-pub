# Connect SIEM log sources

**Goal:** Feed the edge, identity provider and gateway into Wazuh, with decoders and rules that are tested on every deployment.

**Why:** [ADR-0010](../adr/0010-wazuh-as-siem.md). **Accept with:** [ATP-008](../atp/ATP-008-detection.md).

| Source | Path into Wazuh | Decoder | Rules |
|---|---|---|---|
| Caddy (`edge01`) | Container stdout, journald tag `caddy`, agent | `caddy` | 100100-100108 |
| Authentik (`idp01`) | Container stdout, journald tag `authentik`, agent | `authentik` | 100200-100212 |
| Gateway SIEM export (CEF) | Syslog UDP 514 from `wazuh_manager_syslog_allowed_ips` | `unifi-cef`, `unifi-cef-bare` | 100300-100310, 100398-100399 |

Decoders are in `roles/wazuh_manager/templates/labstack_decoders.xml.j2` and rules in `files/labstack_rules.xml`. Each run writes them only when changed, tests with `wazuh-analysisd -t`, restores on failure, restarts the manager, and replays `wazuh_manager_logtest_samples`. **A sample that misses its rule fails the run.**

## Deploy

Dev first, then prod. Switching the log driver recreates Caddy and Authentik containers, causing a few seconds of downtime.

```bash
bin/ap dev playbooks/services.yml --limit 'caddy:authentik:wazuh_manager:wazuh_agents'
```
```bash
bin/ap prod playbooks/services.yml --limit 'caddy:authentik:wazuh_manager:wazuh_agents'
```

## Configure the gateway (one-time, console only)

The SIEM export is not exposed by the API the playbooks use.

1. UniFi Network: Settings, Integrations, choose **SIEM Server**.
2. Server `__SEC_NET__.10`, port `514`.
3. Categories: Security and System at least. Internet is useful. Monitoring is noisy and reaches only level 2.

Firewall entries arrive only for policies with logging on. The explicit block policies already log. The gateway reaches `siem01` from its own zone, so no firewall change is needed.

## Check each source

On `siem01`, syslog from an address outside the allowed list is dropped:
```bash
sudo tcpdump -ni any udp port 514 -c 5
```

On `edge01` and `idp01`:
```bash
sudo journalctl -t caddy -n 3 -o cat
```
```bash
sudo journalctl -t authentik -n 50 -o cat | grep 'Created Event' | tail -3
```

Alerts arriving, on `siem01`:
```bash
cd /opt/wazuh-docker/single-node && sudo docker compose exec -T wazuh.manager tail -n 2000 /var/ossec/logs/alerts/alerts.json | jq -r 'select(.rule.id | test("^100[123]")) | [.timestamp, .rule.id, .rule.level, .rule.description] | @tsv' | tail
```

**Make test alerts:** a wrong password at `auth` gives 100203, and five in five minutes gives 100204. A gateway UI login gives 100303, and a blocked connection gives 100306.

## Add a new event shape

Run `/var/ossec/bin/wazuh-logtest` in the manager container, paste the raw line, and read phase 2 (decoder) and phase 3 (rule). Add the line to `wazuh_manager_logtest_samples` so it stays covered. **Redact real addresses from samples before committing.**

UniFi Network 10.x field names differ from published examples: firewall events carry `UNIFIpolicyType=Firewall`, `act`, and `UNIFIsrcClientIp`/`UNIFIdst*Ip`. The samples are the reference.
