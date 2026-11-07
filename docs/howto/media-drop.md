# Add files to media libraries

**Goal:** Drop files into SMB shares that the media applications read directly.

| Share | Dataset | Application | Expected layout |
|---|---|---|---|
| `audiobooks` | `tank/audiobooks` | Audiobookshelf | `Author/Title/` with audio files and cover |
| `ebooks` | `tank/ebooks` | Audiobookshelf | `Author/Title/book.epub` |
| `music` | `tank/music` | Navidrome | `Artist/Album/01 Track.flac` |
| `media` | `tank/media` | Jellyfin | `Movies/Title (Year)/...`, `Shows/Show/Season 01/...` |

`files01` bind-mounts the datasets. Samba writes everything as `labdata` (UID 2000), the account the applications run as, so a dropped file is never owned by a person. `._*`, `.DS_Store` and `Thumbs.db` are refused.

**Access:** LAN only, for accounts in `samba_users`. SMB is never exposed to the internet. Away from the site, upload through application web pages or Nextcloud.

## Connect

| Client | How |
|---|---|
| macOS | Finder, Connect to Server: `smb://files01.example.com/audiobooks` |
| Windows | Map network drive: `\\files01.example.com\music` |
| Linux | `smb://files01.example.com/media`, or mount with `-o vers=3.1.1` |
| iOS | Files, Connect to Server |
| Android | An SMB3 client |

## Copy large files

Drop into a folder starting with `.`, such as `.incoming/`, and move it into place when finished. Scanners skip hidden folders, so they never import half a file.

Applications pick up files by folder watcher. Enable *real-time monitoring* per library in Jellyfin. Otherwise use a library scan.

## Recover a mistake

Library datasets are snapshotted daily (kept a week) and monthly (kept 3 months) by sanoid. Shares, Syncthing and Nextcloud are snapshotted hourly.

```bash
ssh ansible@pve03 'ls /tank/music/.zfs/snapshot/'
```
```bash
ssh ansible@pve03 'sudo cp -a "/tank/music/.zfs/snapshot/<snapshot>/Artist/Album" /tank/music/Artist/'
```

These snapshots are in the same pool. They cover mistakes, not a lost disk ([limitations](../adr/0011-backup-strategy.md)).

## Roll out

```bash
bin/ap prod playbooks/storage.yml --limit storage_nodes
```
```bash
bin/ap prod playbooks/lxc_host.yml --limit pve03
```
```bash
bin/ap prod playbooks/services.yml --limit files01
```

If a copy gives "permission denied", earlier files are root-owned. Give the libraries to `labdata` once:

```bash
ssh ansible@pve03 'for d in audiobooks ebooks music media; do sudo chown -R 2000:2000 /tank/$d; sudo find /tank/$d -type d -exec chmod 2775 {} +; done'
```
