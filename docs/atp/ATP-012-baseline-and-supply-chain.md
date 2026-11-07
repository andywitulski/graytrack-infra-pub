# ATP-012: Baseline and supply chain

**Objective:** Prove hardening, integrity of downloads, and repository hygiene.

| ID | Test | Steps | Expected |
|---|---|---|---|
| T1 | CIS scan | Wazuh SCA for each host class | Only items in the [exceptions](../compliance/cis-debian13-exceptions.md) fail |
| T2 | sshd baseline | `sudo sshd -T \| grep -E 'permitrootlogin\|passwordauthentication\|maxauthtries'` on a guest | Root login no; password auth off; max tries 4 |
| T3 | Checksums enforced | Change a `*_sha256` to a wrong value; run the role with `--limit` on a dev host | Download refused |
| T4 | No drift | `bin/tf prod plan`; `services.yml --check --diff` | No changes |
| T5 | Secret scanning | `pre-commit run --all-files`, and commit a fake private key on a test branch | Clean run; commit blocked |
| T6 | Publication guard | Add a private address to a test file; run `scripts/check-sanitized.sh` | Reports FAIL |
