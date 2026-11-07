# Control public exposure

**Goal:** Publish selected sites through one inbound path, in an order where each step is safe alone, and be able to close it again.

**Why:** [ADR-0008](../adr/0008-single-edge-and-central-identity.md). **Accept with:** [ATP-006](../atp/ATP-006-edge-and-identity.md). **Site matrix:** [Network and trust zones](../architecture/network-and-trust-zones.md#exposure-per-site).

## Steps (exposure is last)

1. **MFA first.** Expect stages, a flow, bindings, a reputation policy and a brand. From inside, in a private window, you are asked to enroll: enroll two factors.
   ```bash
   bin/tf-ak prod plan && bin/tf-ak prod apply
   ```
   Recovery if locked out, on `idp01`:
   ```bash
   cd /opt/authentik && sudo docker compose exec server ak create_recovery_key 1 akadmin
   ```
2. **App passwords** for clients that cannot do OIDC: one per device.
3. **Caddy and Forgejo.** Internal clients see no change; the guards refuse only non-private sources.
   ```bash
   bin/ap prod playbooks/services.yml --limit caddy,forgejo
   ```
4. **Public DNS.** Records to the WAN address, with Dynamic DNS if it changes. Local DNS keeps internal clients going straight to `edge01`.
5. **Open the door.** Set `unifi_public_exposure: true` in `ansible/network/zone_policy.yml` and commit.
   ```bash
   bin/ap prod playbooks/unifi_firewall.yml
   ```
6. **Verify from outside,** on a phone with Wi-Fi off, and save the output as [evidence](../evidence/README.md).
   ```bash
   for u in auth/ git/ cloud/status.php music/ books/ media/ sync/ auth/if/admin/ cloud/settings/admin; do printf '%-28s ' "$u"; curl -s -o /dev/null -w '%{http_code}\n' "https://${u%%/*}.example.com/${u#*/}"; done
   ```
   | Path | Expected |
   |---|---|
   | `auth/` | 200 or 302 |
   | `git/`, `cloud/status.php`, `books/`, `media/` | 200 |
   | `music/` | 302 to `auth` |
   | `sync/`, `auth/if/admin/`, `cloud/settings/admin` | 403 |
7. **Watch it.** Wazuh parses Caddy (100100-108) and Authentik (100200-212). Expect scanner noise within hours.

## Port forward check

`playbooks/unifi_firewall.yml` writes the forward through the controller's REST API and reads it back. The run fails unless the target is `edge01`.

**Lesson learned:** the collection's module sent the target under the wrong field name, leaving a forward with no destination. Outside connections timed out while every other layer was correct. External TCP checks found it, which is why this read-back exists. `--check` prints differing fields before anything is written.

## Close it

Set `unifi_public_exposure: false` and run the firewall playbook. The forward and the internet policy go away, and nothing else needs changing.
