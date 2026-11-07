# ATP-003: Certificates and SSH

**Objective:** Prove short-lived, attributable access and working revocation.
**Prerequisites:** [CA built](../howto/certificate-authority.md).

| ID | Test | Steps | Expected | Tag |
|---|---|---|---|---|
| T1 | Certificate login | `ssh -v -o IdentitiesOnly=yes -i ~/.ssh/labstack/prod/ansible ansible@git01 true` | Host certificate matched; authenticated; rule 100450 | |
| T2 | Lifetimes | `ssh-keygen -L -f ~/.ssh/labstack/prod/ansible-cert.pub`; repeat for a person's | Automation 8 h, people 16 h, one principal | |
| T3 | Policy refuses unknown names | Request a host certificate for `evil.example.org` | Refused: name not allowed | |
| T4 | Wrong principal refused | Log in as an account your principal is not listed for | Permission denied | |
| T5 | Revocation is effective | Add your test serial to `ssh_ca_revoked`, run `ssh-ca.yml`, log in | Refused; host log shows `revoked by file`. Remove afterward | `drill` |
| T6 | Break-glass raises an alert | `bin/ssh-cert prod breakglass ansible 1`, log in to one guest | Login works; rule 100451 at level 12 | `drill` |
| T7 | Host rebuild stays trusted | Rebuild a test guest and re-sign | No fingerprint prompt | `drill` |
| T8 | Static key refused | `ssh -o IdentitiesOnly=yes -o IdentityAgent=none -i ~/.ssh/id_ed25519_ansible ansible@git01 true` | **After enforce:** Permission denied. **Now:** succeeds, because `ssh_ca_enforce: false` | `after-enforce` |

**Evidence:** Output and SIEM alert excerpts.
