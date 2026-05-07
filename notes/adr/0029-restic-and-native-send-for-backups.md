# ADR-0029: Restic and Native Send for Volume Backups

**Status**: Accepted
**Date**: 2026-04-12

## Context

Service volumes on worker nodes contain application data (databases, file uploads, etc.) that must be backed up. Unlike the controller state DB (see [ADR-0028](0028-operator-managed-state-backup.md)), volume backups run on remote nodes and need scheduling, retention policies, and pre/post hooks (e.g., `pg_dump` before backup).

Key forces:

- Volume backups must run on the node where the volume lives — data should not transit through the controller.
- Backup scheduling should be reliable and survive node reboots.
- Different volume drivers (see [ADR-0025](0025-filesystem-driver-abstraction.md)) have different optimal backup methods — BTRFS/ZFS have efficient native send/receive, while `directory` volumes need a general-purpose tool.
- Podmander generates configuration; backup tools execute. Same pattern as all other managed components.

## Decision

Podmander supports two backup methods, chosen per volume:

1. **Restic** — general-purpose backup tool. Works with all volume drivers. Supports deduplication, encryption, and multiple storage backends (S3, SFTP, local).
2. **Native send** — filesystem-native `btrfs send` or `zfs send`. Available only for snapshot-capable volumes. Efficient incremental transfers.

Podmander generates backup configuration (Restic config, wrapper scripts with pre/post hooks) and systemd timers. These are transferred to the node via SSH and execute independently — no controller involvement after setup.

Backup status, manual triggers, and restore operations are available via the CLI, which SSHes to the node to query or execute.

## Consequences

### Positive

- Backups run on the node — no data transits through the controller.
- systemd timers are reliable and survive reboots.
- No controller involvement after setup — backups continue even if the controller is down.
- Restic provides deduplication, encryption, and broad storage backend support out of the box.
- Native send/receive provides efficient incremental transfers for snapshot-capable volumes.
- Pre/post hooks enable application-level quiescence (e.g., `pg_dump`, `pg_checkpoint`).

### Negative

- Restic must be installed on nodes with backup-configured volumes (handled during bootstrap for storage nodes).
- Two backup methods to implement and document.
- Backup failures are only visible when the operator checks status — no built-in alerting (integration with monitoring is a future extension).

### Neutral

- Backup configuration is not versioned like infrastructure components — it changes rarely and regeneration from the stack TOML is straightforward.

## Alternatives Considered

### Controller-mediated backups

- Pros: Centralized backup management, single point of visibility.
- Cons: Data must transit through the controller — bandwidth bottleneck, latency, controller becomes a critical path for backups. Controller downtime stops backups.
- Why rejected: Unnecessary data transit. Node-local execution is simpler, faster, and more resilient.

### Restic only (no native send/receive)

- Pros: One tool to implement and document. Restic works with all filesystems.
- Cons: Misses the efficiency of native send/receive for BTRFS/ZFS. Incremental `btrfs send` transfers only changed blocks at the filesystem level — Restic must read and deduplicate all files.
- Why rejected: Native send/receive is significantly more efficient for snapshot-capable volumes. Both methods are straightforward to implement since Podmander only generates configuration.

### Built-in backup implementation

- Pros: No external tool dependencies.
- Cons: Reimplements proven backup functionality (deduplication, encryption, retention, incremental transfers). Massive scope increase. Testing burden.
- Why rejected: Violates the core philosophy — Podmander generates configuration, proven tools execute.

## References

- [ADR-0028](0028-operator-managed-state-backup.md) — Operator-managed state DB backup (separate concern)
- [ADR-0025](0025-filesystem-driver-abstraction.md) — Filesystem driver abstraction
- [ADR-0027](0027-snapshots-linked-to-versions.md) — Snapshots linked to service versions
