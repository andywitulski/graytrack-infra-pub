# Set up file shares and migrate repositories

**Goal:** Serve SMB shares from `files01` and move local git repositories into Forgejo.

## Set up SMB

Shares are defined in `inventories/common/group_vars/samba.yml`. Each private share is its own ZFS dataset with hourly snapshots.

```bash
bin/ap prod playbooks/storage.yml --limit storage_nodes
```
```bash
bin/ap prod playbooks/lxc_host.yml
```
```bash
bin/ap prod playbooks/services.yml --limit files01 -e ansible_user=root
```
```bash
bin/ap prod playbooks/services.yml --limit files01
```
```bash
ssh ansible@files01 sudo smbpasswd -a alice
```

Samba passwords are set by hand. Mount with encryption:

```bash
sudo mount -t cifs //files01.example.com/alice_priv /mnt/alice_priv -o username=alice,uid=$(id -u),gid=$(id -g),vers=3.1.1,seal,mfsymlinks
```

**Keep keys out of shares.** When copying a home directory, exclude `.ssh/`, `.gnupg/` and `.config/sops/`. They belong offline.

## Migrate repositories

Push-to-create makes a repository on first push, private by default. Set up [git over SSH](using-certificates.md#git-over-ssh) first.

1. Turn on push-to-create for the migration only.
   ```bash
   bin/ap prod playbooks/services.yml --limit forgejo -e forgejo_push_create=true
   ```
2. Find repositories. Review the list, dropping clones of other people's projects. Names must be unique. Commit uncommitted work first: only committed branches and tags move.
   ```bash
   find ~ -xdev \( -name node_modules -o -path ~/.cache \) -prune -o -type d -name .git -print 2>/dev/null | sed 's|/\.git$||' | sort > ~/repos.txt
   ```
3. Push.
   ```bash
   while read -r r; do n=$(basename "$r"); git -C "$r" remote add forgejo "git@git.example.com:alice/$n.git" 2>/dev/null; git -C "$r" push forgejo --all && git -C "$r" push forgejo --tags && echo "ok  $n" || echo "FAIL $n"; done < ~/repos.txt
   ```
4. Turn push-to-create off again.
   ```bash
   bin/ap prod playbooks/services.yml --limit forgejo
   ```
