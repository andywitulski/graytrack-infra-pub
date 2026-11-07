# Mirror git offsite

**Goal:** Push every Forgejo repository to a private GitHub organization that exists only for backups.

**Why:** [ADR-0011](../adr/0011-backup-strategy.md).

| Piece | Location |
|---|---|
| Playbook | `ansible/playbooks/forgejo_mirrors.yml`, runs on the controller, weekly from `paw01` |
| Settings | `inventories/prod/group_vars/all/forgejo_mirrors.yml` |
| Tokens | OpenBao `kv/services/prod/forgejo` |
| Push path | `git01` to `github.com:443`; no SSH out |
| Backup name | `<owner>--<repo>` |

Forgejo pushes on every push and every 8 hours as a backstop.

**What it is:** a copy of every branch, tag, commit and LFS object.

**What it is not:** protection against mistakes, since a deleted branch or force push is mirrored within hours. Issues, pull requests, releases and users are in Forgejo's database and are not mirrored. Mistakes are covered by Forgejo's nightly dump and PBS.

## Set up

1. **Create the organization.** Free plan, you as the only member, base permission "No permission", repository creation off for members.
2. **Create a GitHub fine-grained token.** Resource owner: the organization. Expiry: a year, with a calendar reminder. All repositories. Permissions: Administration, Contents, and Workflows read and write (GitHub refuses pushes containing workflow files without the last).
3. **Create a Forgejo token.** Admin user, scopes `read:user`, `read:organization`, `write:repository`.
4. **Store both and set the org.**
   ```bash
   bin/bao-secret prod set forgejo_mirror_github_token
   ```
   ```bash
   bin/bao-secret prod set forgejo_mirror_api_token
   ```
   Set `forgejo_mirror_github_org: your-backup-org` and commit.
5. **First run.** Large repositories may still be pushing when it reports. A first push shows `never` and no error. Run it again later.
   ```bash
   bin/ap prod playbooks/forgejo_mirrors.yml
   ```

The run fails if any mirror's last sync failed, naming the repository and error.

## Replace the token

Forgejo keeps the token inside each mirror.

```bash
bin/bao-secret prod set forgejo_mirror_github_token
```
```bash
bin/ap prod playbooks/forgejo_mirrors.yml -e forgejo_mirror_recreate=true
```

## Restore

```bash
git clone --mirror https://github.com/your-backup-org/alice--labstack-infra.git
```
```bash
cd alice--labstack-infra.git && git push --mirror ssh://git.example.com:2222/alice/labstack-infra.git
```

If the repository no longer exists in Forgejo, create it empty first, or run with `forgejo_push_create: true`. The play never deletes on GitHub.

**Do not mirror a private repository into a public space.** The backup organization must keep its repositories private.
