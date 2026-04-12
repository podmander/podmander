# Backups Specification

Backup configuration for local state and service volumes.

For architectural decisions and rationale, see:
- [ADR-0028](../adr/0028-operator-managed-state-backup.md) — Operator-managed state DB backup
- [ADR-0029](../adr/0029-restic-and-native-send-for-backups.md) — Restic and native send for volume backups

## Local State Backup

The operator's local SQLite database contains critical state:
- Service definitions and version history
- Encrypted secrets
- Node metadata
- Deployment logs

Location: `~/.local/share/podmander/podmander.db`

Operators back this up using their existing workstation backup strategy (Time
Machine, Restic, manual copies, etc.). The master encryption key (if stored as
a file) should be backed up separately and securely.

## Volume Backups

Opt-in per volume in TOML configuration. Podmander generates backup
configuration; systemd timers and backup tools execute on the nodes.

### Configuration

```toml
[volume.postgres-data.backup]
method = "restic"                         # or "send" for BTRFS/ZFS volumes
repository = "s3:s3.amazonaws.com/bucket/postgres"
schedule = "daily"
retain = { daily = 7, weekly = 4, monthly = 6 }
pre_hook = "pg_dump -U postgres > /backup/dump.sql"
```

### Generated Artifacts

On deploy, Podmander copies to the node via SSH:
- Restic configuration file
- Systemd timer and service unit for scheduled execution
- Wrapper script with pre/post hooks

```
~/.config/systemd/user/podmander-backup-postgres-data.timer
~/.config/systemd/user/podmander-backup-postgres-data.service
~/.config/podmander/backup-postgres-data.sh
```

### Execution

Backups run on the node via systemd timer — no Podmander involvement after
setup.

### Filesystem-Native Backups

Snapshot-capable volumes (BTRFS, ZFS) can use their native send/receive for
efficient incremental backups. See [Volume Snapshots](volume-snapshots.md).

## CLI Commands

```bash
podmander backup status              # SSH to nodes, check timer status
podmander backup run postgres-data   # Trigger immediate backup
podmander backup list postgres-data  # List snapshots in repository
```

## Restore

```bash
podmander volume restore postgres-data --snapshot latest
podmander volume restore postgres-data --snapshot 2024-01-15T10:30:00
```

Restore process:
1. Stop services using the volume
2. SSH to node, run Restic restore (or `btrfs receive`/`zfs receive`)
3. Restart services

## Open Items

- Backup verification/restore testing automation
- Alerting on backup failures (integrate with monitoring)
- Cross-node restore (restore volume to different node than original)
