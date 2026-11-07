# CIS Debian 13 benchmark: exceptions register

Findings from the Wazuh SCA policy `cis_debian13`. The scan of 2026-10-10 reported 111 failed checks on an unprivileged LXC, where kernel, boot, partition and audit checks cannot pass by design. This is the decision record per group. Rescan after `services.yml` (guests) and `telemetry-baseline.yml` (nodes).

| Checks | Topic | Decision | Rationale |
|---|---|---|---|
| 33157-33173, except 33157 | sshd: root login, forwarding, tries, grace, MACs, banner | **Fixed** | `roles/cis_baseline`. Nodes keep `prohibit-password` and forwarding, which cluster SSH and live migration require |
| 33157 | sshd AllowUsers | Accepted | Key-only, one automation account, network limits SSH to admins; an allow list adds lockout risk |
| 33048, 33050 | Banners | **Fixed** | Nodes: `/etc/issue` left to pvebanner |
| 33178, 33181 | sudo log, timeout | **Fixed** | Also `use_pty` |
| 33182 | su restricted | **Fixed** | `pam_wheel` with an empty group |
| 33099-33104 | Cron permissions | **Fixed** | |
| 33089 | telnet client | **Fixed** | Removed |
| 33234 | journald compression | **Fixed** | |
| 33296 | `opasswd` permissions | **Fixed** | |
| 33245, 33253-33271 | auditd and CIS rules | **Fixed** on VMs and nodes | LXCs cannot load audit rules, since the kernel is the host's |
| 33272 | Audit immutable (`-e 2`) | **Compensated** | A change would otherwise wait for a reboot. Every event is copied off-host, and touching audit config alerts at level 10 (100431, 100434) |
| 33248 | `audit_backlog_limit` | Deferred | Boot parameter; next kernel maintenance |
| 33250-33252 | Never delete logs, halt when full | Accepted | Availability first: a full disk must not halt the storage node or SIEM |
| 33010-33035 | Separate partitions and options | Accepted | Cloud images and LXCs use one root filesystem; little value for single-purpose guests |
| 33017 | `/dev/shm` noexec | Deferred | Some container runtimes need exec; test on one host first |
| 33039, 33040 | AppArmor | Deferred | Present by default on VMs and nodes; confirm the failing host first |
| 33043 | Bootloader password | Accepted | Console access means Proxmox admin, which already owns the guest |
| 33072, 33075 | NFS, rpcbind | Accepted on `pve03` | It is the NFS server |
| 33094, 33096 | timesyncd and chrony user | Accepted | chrony is chosen; only one can run |
| 33126-33151 | Host firewall | **Fixed outside the guest** | Proxmox guest firewall, enforced on the node. The in-guest scan cannot see it. Inbound default deny applies only once enforced ([G-02](gap-register.md)) |
| 33179 | Password for sudo | Accepted | The automation account has no password; its logins are pinned to controllers (rule 100402) |
| 33185-33212 | PAM password quality, lockout, aging | Accepted on guests | No account has a password. Revisit for nodes' root password |
| 33217, 33300 | Root access, shadowed passwords | False positive | Checked 2026-10-10 on all hosts |
| 33229-33238 | journal-remote, rsyslog | Accepted | Logs leave through the Wazuh agent |
| 33284, 33285 | AIDE | Accepted | Wazuh syscheck is the FIM |
