# Git workflow

## Rules

- Pull before you start; push when you stop.
- Use a branch for anything you will run against prod. Merge after it has worked.
- Check that sops files are encrypted before committing them.
- Never force-push `main`. Use `--force-with-lease` only on your own branches.
- The scheduled jobs on `paw01` run from its clean `main`: after a merge, `git pull` there too.
- Name commits `area: what changed`, for example `media: add ebooks library`.

## Topology

This describes the private repository. The public edition is a separate repository, with no shared history.

| Remote | Role |
|---|---|
| Forgejo | Primary, self-hosted |
| GitHub, private | Off-site copy |
| Public edition | Sanitized snapshot only. **Never add it as a remote of the private repository** |

## Everyday

| Task | Command |
|---|---|
| State | `git status -sb` |
| Update | `git pull` |
| Stage specific files | `git add <file>` |
| See what will be committed | `git diff --cached` |
| New branch | `git switch -c feat/thing` |
| First push | `git push -u origin feat/thing` |

Check encryption before committing a secrets file. A plain-text secret in git is in the history for good.

```bash
sops filestatus ansible/inventories/prod/group_vars/all/secrets.sops.yml
```

## Merge and clean up

```bash
git switch main && git pull
```
```bash
git merge --ff-only feat/thing
```
```bash
git push
```
```bash
git branch -d feat/thing
```

`-d` refuses if unmerged. Before using `-D`, check what you would lose with `git log --oneline main..feat/thing`.

## Undo

| Situation | Command |
|---|---|
| Discard changes to a file | `git restore <file>` |
| Unstage a file | `git restore --staged <file>` |
| Undo the last commit, keep changes (unpushed) | `git reset --soft HEAD~1` |
| Undo a pushed commit | `git revert <sha>`, then push |
| Lost a commit | `git reflog`, then `git branch rescue <sha>` |

`reset --hard` and `restore` destroy uncommitted work with no undo. Stash first if in doubt.

## Publish to the public edition

1. Regenerate from the private repository with the private sanitizer, which lives outside both repositories.
2. Review the diff by eye.
3. Run the guard, with the private denylist:
   ```bash
   SANITIZE_DENYLIST=~/private/denylist.txt scripts/check-sanitized.sh
   ```
4. Commit with an identity you are happy to publish.

If something sensitive reaches the public repository, treat it as permanently disclosed: rotate it first, then rewrite history. See [Incident response](../runbooks/incident-response.md).
