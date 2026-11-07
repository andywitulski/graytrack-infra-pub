# Weekly tasks

About 45 minutes, in a quiet hour outside the 02:00 backup window.

## 1. Patch

Follow [Patching](../runbooks/patching.md). Start with dev if the change is large.

```bash
bin/ap prod playbooks/patch.yml --check
```
```bash
bin/ap prod playbooks/patch.yml
```

Read the summary line for each host. Schedule reboots for anything marked `needed`.

**Expected:** the run completes. A health check failure stops the run on that host: fix it before continuing.

## 2. Review Renovate pull requests

Handle the security label first. For each: read the release notes, update `*_sha256` if needed, merge, and [deploy](../runbooks/patching.md#update-an-application).

## 3. Confirm the certificate timer ran

`labstack-renew-certs` runs Monday around 04:30.

```bash
ssh ansible@paw01 'systemctl list-timers labstack-renew-certs.timer; systemctl status labstack-renew-certs --no-pager'
```

**Expected:** last run under a week ago and not failed. **If `paw01` has an outdated checkout:** `git pull` there.

## 4. Check for drift

Each should show no changes. Anything else is either an unrecorded change, which you investigate, or a needed update, which you commit.

```bash
bin/tf prod plan
```
```bash
bin/tf-platform prod plan
```
```bash
bin/tf-ak prod plan
```
```bash
bin/ap prod playbooks/services.yml --check --diff
```

## 5. Review vulnerabilities

In Wazuh: Vulnerability Detection, sorted by severity. For each critical or high CVE, decide whether to patch now, whether it is unreachable in this deployment, or whether to record an exception.

## 6. Review firewall audit events

While `firewall_enforce` is off, review rule 100421. Add a rule for each legitimate flow, and investigate the rest. **Goal:** a quiet week, then [enforce](../howto/host-firewall.md#3-enforce).

## 7. Check mirrors and capacity

The weekly job reports mirror failures. Check disk space:

```bash
ssh ansible@pve03 'sudo zpool list; sudo zfs list -o name,used,avail -r tank | head -20'
```

**Action threshold:** plan expansion at 80% pool usage. PBS datastore growth is the usual cause, so review retention if it is climbing.
