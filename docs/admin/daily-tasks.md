# Daily tasks

About 10 minutes. Record anything abnormal, and open an [incident](../runbooks/incident-response.md) if it looks like compromise.

## 1. Get a credential

Open a certificate session. With `autorenew` installed, this is already done.

```bash
bin/ssh-cert prod login alice@example.com
```
```bash
bin/ssh-cert prod status
```

**Expected:** a valid certificate. **If it fails:** see [troubleshooting](../howto/using-certificates.md#troubleshooting).

## 2. Review security alerts

Open `https://siem.example.com` from an admin path, then Threat Hunting with the last 24 hours and level 10 or above.

| Rule | Meaning | Action |
|---|---|---|
| 100451 | Break-glass certificate used | Was it you? If not, **critical incident** |
| 100402 | Automation account from an unexpected address | Investigate at once |
| 100452 | Plain key login after cutover | Find the standing key |
| 100208 | User impersonation | Confirm with the admin |
| 100434, 100431 | Audit configuration changed outside Ansible | Investigate |
| 100204, 100103 | Repeated failed logins | Check source and account; expect some on public sites |
| 100423 | Many firewall drops | Scan or lateral movement. Check the source zone |
| 100309, 100310 | Gateway threat | Read the signature and source |
| 100442 and neighbors | ZFS or backup failure | Go to step 3 |

Then check Authentik failures and any login from an unfamiliar location.

**Expected:** nothing unexplained. Internet scanner noise at lower levels is normal.

## 3. Check last night's backups

Backups run at 02:00, and `labnode` at 02:30. Wazuh alerts on a failed job. To confirm directly:

```bash
ssh ansible@pbs01 'sudo proxmox-backup-manager task list --limit 20'
```

**Expected:** every guest OK. **If one failed:** rerun for that guest before tonight, and find the cause.

```bash
ssh ansible@<node> 'sudo vzdump <vmid> --storage pbs01 --mode snapshot'
```

## 4. Check platform health

```bash
ssh ansible@pve01 'sudo pvecm status | grep -E "Quorate|Total votes"'
```
```bash
source bin/lib/platform.sh && platform_env prod "$PWD"
```
```bash
curl -s --cacert "$BAO_CACERT" "$BAO_ADDR/v1/sys/health" | jq '{initialized, sealed}'
```
```bash
curl -s --cacert "$PLATFORM_CA_ROOT" "$PLATFORM_CA_URL/health"
```
```bash
ssh ansible@pve03 'sudo zpool status -x'
```

**Expected:** `Quorate: Yes`; `sealed: false`; `{"status":"ok"}`; `all pools are healthy`.

## 5. Check public services

```bash
for u in auth git cloud books; do printf '%-8s' "$u"; curl -sS -o /dev/null -w '%{http_code}\n' "https://$u.example.com"; done
```

**Expected:** 200 or 302. A 502 means the backend is down; a certificate error means Caddy is failing to renew (rule 100108).

## 6. Review the Headscale rejected list (when devices were added)

```bash
ssh ansible@hs01 'sudo headscale nodes list'
```

An unfamiliar device means someone signed in with valid credentials. Treat it as a possible account compromise.
