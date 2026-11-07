# Add a service

The repeatable path to a new application, using the order from past rollouts. Each step is safe alone, and public exposure is last.

1. **Decide.** Does it warrant an ADR? Where does it belong: VM or LXC, which zone, which node? What identity integration: OIDC, forward auth, or none?
2. **Add it to the inventory:** `inventories/prod/hosts.yml`, with a role group. Plays target groups, not hosts.
3. **Write or reuse a role.** Use `roles/compose_app` for Docker stacks. Pin the exact version with a `# renovate:` comment.
4. **Secrets.** Add to `bin/gen-service-secrets`, and run it. Client secrets created by OpenTofu go in `tofu_owned`.
   ```bash
   bin/gen-service-secrets prod
   ```
5. **Identity.** Add a file in `tofu/modules/authentik_config`: group, provider, application, binding. Write the client secret to OpenBao from `openbao.tf`. Apply it.
6. **Guest and firewall.** Add to `tofu/envs/prod/services.tf` or `lxc.tf`, and add `guest_rules`. The plan must show only the new guest and its rules.
   ```bash
   bin/tf prod plan && bin/tf prod apply
   ```
7. **Zone policy.** Add `unifi_<name>` and allows. Edge to backend is the usual one.
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml --check --diff
   ```
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml
   ```
8. **CA.** `ca01` signs only names in the inventory as of its last run.
   ```bash
   bin/ap prod playbooks/platform.yml --limit step_ca
   ```
9. **Configure.** An LXC's first run is as root. A service with a first-run claim page must be claimed in this run, before any DNS exists ([example](../howto/audiobookshelf.md)).
   ```bash
   bin/ap prod playbooks/services.yml --limit <host>
   ```
10. **Edge and local DNS.** Add a `caddy_sites` entry. It defaults to internal only. List admin paths in `lan_paths`.
    ```bash
    bin/ap prod playbooks/services.yml --limit caddy
    ```
    ```bash
    bin/ap prod playbooks/unifi_dns.yml
    ```
11. **Backups:** covered automatically by the nightly job. Application databases get a nightly dump through `roles/compose_app`.
12. **Monitoring:** the agent comes from `services.yml`. Add decoders, rules and samples for security-relevant logs.
13. **Public,** only if needed: set `public: true` and add the DNS record. Verify from outside.
14. **Document it.** Add a how-to, a row in the inventory table, a [control mapping](../compliance/README.md) note if it changes exposure, and an ATP entry.
