# ansible/files: generated, environment-specific artifacts

This directory is empty on purpose. The private repository this one was derived from keeps public
certificates and device identity records here. They are excluded because they identify a real environment.
Each is created while you build yours, then committed to your private fork.

| Path | Created by | Purpose |
|---|---|---|
| `<env>/pg01-ca.pem`, `<env>/bao01-ca.pem`, `labnode/gpu01-ca.pem` | `roles/host_tls` | pin the per-host CA of a platform service |
| `<env>/bao01-trust.pem` | `roles/openbao` | transition bundle: the per-host CA plus the root |
| `<env>/ca01-root.pem`, `ca01-intermediate.pem`, `ca01-ssh-*.pub` | `bin/ca-init` | public trust anchors |
| `<env>/ldap-outpost-ca.pem` | `bin/tf-ak <env> output -raw ldap_ca_pem` | LDAP outpost CA |
| `<env>/wazuh-saml-metadata.xml` | `bin/tf-ak <env> output -raw wazuh_saml_metadata` | IdP metadata for the SIEM |
| `<env>/tpm/*.yml`, `<env>/tpm/swtpm-localca/*` | `roles/tpm` (`playbooks/tpm.yml`) | endorsement key pins |
| `pubkeys/ansible.pub`, `tofu.pub`, `labadmin.pub` | you | bootstrap SSH keys for first runs |

Roles treat a missing file as "not built yet" where that is safe: `ssh_ca_enabled` stays false until
`ca01-ssh-user-ca.pub` exists.
