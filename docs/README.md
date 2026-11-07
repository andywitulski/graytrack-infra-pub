# Documentation

| Section | Contents | Audience |
|---|---|---|
| [architecture/](architecture/overview.md) | Design, trust zones, identity and secrets model | Everyone |
| [adr/](adr/README.md) | Architecture decision records | Engineers, reviewers |
| [howto/](howto/README.md) | Task guides to build and change components | Engineers |
| [runbooks/](runbooks/README.md) | Disaster recovery, patching, rotation, compromise and break-glass response | On-call admin |
| [admin/](admin/README.md) | Daily, weekly, monthly and yearly walk-throughs; access lifecycle; git workflow | Admins |
| [atp/](atp/README.md) | Acceptance test procedures with pass criteria | Admins, auditors |
| [compliance/](compliance/README.md) | Control mapping to NIST CSF 2.0, SP 800-53, SP 800-207, CIS Controls and Top 10 lists | Auditors, reviewers |
| [evidence/](evidence/README.md) | How test evidence is captured, with redacted samples | Auditors |

## Conventions

- **Tokens.** `__MGMT_NET__.22` is an address with a placeholder prefix; see
  [placeholders.example.env](../config/placeholders.example.env).
- **Angle brackets.** `<host>` and `<vmid>` are values you supply when you run the command.
- **Host names.** Guides write `ssh ansible@hs01`. Use the host's name or address.
- **Environments.** `prod` is the production cluster, `labnode` the standalone node, and `dev` the nested
  test cluster. Examples use `prod` unless stated otherwise.
- **Wrappers.** `bin/ap` runs Ansible and `bin/tf` runs OpenTofu, each with the right credentials. `bin/ap prod`
  and `bin/tf prod` ask for typed confirmation.
- **Commands run from the repository root** on a controller unless they start with `ssh`.
