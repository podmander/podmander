# Volume Snapshots Specification

Snapshot-capable volume management using copy-on-write filesystems.

For architectural decisions and rationale, see:
- [ADR-0025](../adr/0025-filesystem-driver-abstraction.md) — Filesystem driver abstraction
- [ADR-0026](../adr/0026-btrfs-default-zfs-optional.md) — BTRFS as recommended default
- [ADR-0027](../adr/0027-snapshots-linked-to-versions.md) — Snapshots linked to service versions

## Filesystem Support

| Driver | Availability | Snapshot | Send/Receive |
|--------|-------------|----------|--------------|
| `directory` | Any | No | No |
| `btrfs` | All Linux | Yes | Yes |
| `zfs` | Manual setup | Yes | Yes |

## Volume Driver Operations

| Operation | BTRFS | ZFS |
|-----------|-------|-----|
| Create | `btrfs subvolume create` | `zfs create` |
| Snapshot | `btrfs subvolume snapshot -r` | `zfs snapshot` |
| List snapshots | `btrfs subvolume list -s` | `zfs list -t snapshot` |
| Delete snapshot | `btrfs subvolume delete` | `zfs destroy` |
| Send (full) | `btrfs send` | `zfs send` |
| Send (incremental) | `btrfs send -p` | `zfs send -i` |
| Receive | `btrfs receive` | `zfs receive` |

### Rollback Differences

ZFS has a native `zfs rollback` command. BTRFS requires:

1. Stop services using the volume
2. Rename current subvolume
3. Create new snapshot from the target snapshot
4. Start services

The CLI abstracts this difference.

## Configuration

### BTRFS Volume

```toml
[volume.postgres-data]
driver = "btrfs"
path = "/srv/containers/postgres"
```

The path must be on a BTRFS filesystem. Podmander creates a subvolume at this
path if it doesn't exist.

### ZFS Volume

```toml
[volume.postgres-data]
driver = "zfs"
dataset = "tank/containers/postgres"
properties = { compression = "lz4", quota = "50G" }
```

### Snapshot Policy

```toml
[volume.postgres-data.snapshots]
on_deploy = true    # Snapshot before each deploy of dependent services
retain = 5          # Keep last 5 deploy snapshots
```

### Filesystem-Native Backups

```toml
[volume.postgres-data.backup]
method = "send"                           # uses btrfs send or zfs send
destination = "ssh://backup-server/backups/postgres"
schedule = "daily"
incremental = true
retain = 30
```

For application-level quiescence:

```toml
[volume.postgres-data.backup]
method = "send"
destination = "ssh://backup-server/backups/postgres"
pre_hook = "podman exec postgres pg_checkpoint"
```

## Storage Schema

```sql
CREATE TABLE volumes (
    name TEXT PRIMARY KEY,
    driver TEXT NOT NULL DEFAULT 'directory',
    driver_config TEXT,      -- JSON: path/dataset, properties, etc.
    node TEXT,               -- Owning node (NULL if unassigned)
    created_at TEXT NOT NULL
);

CREATE TABLE volume_snapshots (
    id INTEGER PRIMARY KEY,
    volume_name TEXT NOT NULL REFERENCES volumes(name),
    snapshot_name TEXT NOT NULL,
    service_version_id INTEGER REFERENCES service_versions(id),
    snapshot_type TEXT NOT NULL,  -- 'deploy', 'manual', 'backup'
    created_at TEXT NOT NULL,
    retained INTEGER DEFAULT 1,   -- 0 = marked for pruning
    UNIQUE(volume_name, snapshot_name)
);

CREATE INDEX idx_volume_snapshots_by_service
    ON volume_snapshots(service_version_id)
    WHERE service_version_id IS NOT NULL;
```

## Lifecycle Integration

### Service Deploy Flow

1. Resolve volumes mounted by service
2. For each snapshot-capable volume with `snapshots.on_deploy = true`:
   - SSH to node, create read-only snapshot
   - Record in `volume_snapshots` with link to new service version
3. Generate Quadlet with volume mounts
4. Proceed with normal deploy
5. On success: prune snapshots beyond retain count
6. On failure: snapshot remains for forensics

### Rollback Flow

```
$ podctl rollback api

Rolling back api from v5 to v4...

Volume 'postgres-data' has a snapshot from v4 deployment:
  postgres-data@v4-pre-1705312200 (2024-01-15 09:30:00)

Roll back volume to this snapshot? [y/N] y

> Stopping api
> Rolling back postgres-data to @v4-pre-1705312200
> Deploying api v4
Done
```

If the user declines volume rollback:

```
Warning: Rolling back api to v4 without rolling back volume 'postgres-data'.
  Data written since v4 deployment will remain. Proceed? [y/N]
```

### Snapshot Pruning

Pruning respects the retain count and never deletes snapshots linked to:
- The currently active service version
- Any failed service version (forensic value)
- Manual snapshots (explicit user intent)

## Privilege Model

Snapshot operations require elevated privileges. Nodes with snapshot-capable
volumes must use `mode = "rootful"`.

## Node Setup

### BTRFS

```bash
podctl node setup-snapshots storage-1 --driver btrfs --path /srv/containers
```

### ZFS

```bash
podctl node setup-snapshots storage-1 --driver zfs --dataset tank/containers
```

## CLI

### Volume Commands

```bash
podctl volume list                              # Shows driver, node, snapshot count
podctl volume show <name>                       # Details including snapshots
podctl volume create <name> --driver btrfs --path /srv/containers/foo
podctl volume destroy <name>                    # Requires confirmation
```

### Snapshot Commands

```bash
podctl volume snapshots <name>                  # List snapshots with linked versions
podctl volume snapshot <name>                   # Create manual snapshot
podctl volume rollback <name> --to <snapshot>   # Rollback (stops dependent services)
podctl volume prune <name>                      # Remove snapshots beyond retain policy
```

### Snapshot List Output

```
SNAPSHOT                        TYPE    SERVICE  VERSION  CREATED
@v5-pre-1705398600              deploy  api      v5       2024-01-16 10:30:00
@v4-pre-1705312200              deploy  api      v4       2024-01-15 09:30:00
@manual-1705300000              manual  -        -        2024-01-15 06:06:40
@v3-pre-1705225800              deploy  api      v3       2024-01-14 09:30:00
@backup-daily-1705363200        backup  -        -        2024-01-16 00:00:00
```

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| Volume rollback with service running | Stop dependent services, rollback, restart. Warn about downtime. |
| Subvolume/dataset doesn't exist at deploy time | Create with default properties. |
| Parent path not on BTRFS | Error: "Path is not on a BTRFS filesystem." |
| Snapshot target doesn't exist | Error with available snapshots listed. |
| Snapshots not configured on node | Error: "Node lacks snapshot support. Run `podctl node setup-snapshots`." |
| Mixed driver volumes per service | Allowed. Snapshot-capable volumes snapshot; directory volumes get warning on rollback. |
| Multiple services share a volume | Snapshot triggers on any dependent service deploy. |
| Rollback to version with no snapshot | Warning: "No snapshot exists for v2. Volume will retain current state." |

## Open Items

- Compression settings for BTRFS subvolumes
- Quota enforcement via BTRFS qgroups
- Property change detection and application
- Encryption integration
- Cross-node volume migration
