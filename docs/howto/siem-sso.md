# Add SSO to the SIEM dashboard

**Goal:** Sign in to the Wazuh dashboard through Authentik SAML, mapping groups to roles, with password login kept as break-glass.

| Piece | Location | Function |
|---|---|---|
| Groups, provider, mapping | `tofu/modules/authentik_config/wazuh.tf` | `wazuh-administrators`, `wazuh-readonly-users` to backend roles |
| Authentication domains | `roles/wazuh_manager/tasks/sso.yml` | Password first (no challenge), SAML second |
| Indexer and API permissions | Same | Own roles mapped to backend roles; reserved mappings untouched |

The indexer reads IdP metadata from a file in the repository, so `siem01` never contacts Authentik and needs no new firewall rule.

## Reach the dashboard

`siem01` is reachable only from admin addresses. From elsewhere, use a SOCKS tunnel to `paw01` so the browser keeps the real name. SAML posts back to `https://siem.example.com/_opendistro/_security/saml/acs`, so an `ssh -L` port forward would break it.

```bash
ssh -f -N -D 127.0.0.1:1080 -o ExitOnForwardFailure=yes paw01
```
```bash
open -na "Google Chrome" --args --user-data-dir="$HOME/.chrome-siem" --proxy-server="socks5://127.0.0.1:1080" --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE 127.0.0.1" "https://siem.example.com"
```

## Roll out

Do this in dev first when dev is built.

1. Generate the secret and create objects. Expect 2 groups, a mapping, a provider, an application and 2 bindings.
   ```bash
   bin/gen-service-secrets prod
   ```
   ```bash
   bin/tf-ak prod plan && bin/tf-ak prod apply
   ```
2. Save the metadata, then commit it. The temporary file avoids an empty result if the output fails.
   ```bash
   bin/tf-ak prod output -raw wazuh_saml_metadata > /tmp/wazuh-meta.xml && echo >> /tmp/wazuh-meta.xml && mv /tmp/wazuh-meta.xml ansible/files/prod/wazuh-saml-metadata.xml
   ```
3. Add yourself to `wazuh-administrators` and a test account to `wazuh-readonly-users`.
4. Deploy. The first run recreates the indexer once, costing a minute without search.
   ```bash
   bin/ap prod playbooks/services.yml --limit wazuh_manager
   ```

## Test

1. Single sign-on leads to the dashboard, showing your username.
2. Server management, Security shows your session mapped to `administrator`.
3. The read-only account loads dashboards but can change nothing.
4. A user in neither group is refused by Authentik.
5. The `admin` password login still works.

Every login shows as rule 100212.

## Roll back

The role saved the earlier configuration at `/opt/wazuh-docker/single-node/backups/securityconfig-before-saml.json` on `siem01`.

1. Load it into the indexer with `securityadmin.sh -t config` (convert the JSON to YAML first).
2. Delete `wazuh-saml-metadata.xml` so the role stops re-adding SAML.
3. Remove the SAML block from `opensearch_dashboards.yml` and restart the dashboard.
