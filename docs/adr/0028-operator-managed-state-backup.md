# ADR-0028: Operator-Managed State DB Backup

**Status**: Accepted
**Date**: 2026-04-12

## Context

The controller's SQLite database contains critical state: service definitions, version history, encrypted secrets, node metadata, and deployment logs (see [ADR-0003](0003-sqlite-for-controller-state.md)). Losing this database means losing the fleet's desired and expected state. A backup strategy is essential.

Key forces:

- The database is a single file on the controller node.
- Operators already have workstation backup strategies (Time Machine, Restic, cloud sync, manual copies).
- Building backup infrastructure into Podmander would duplicate functionality that operators already have.
- The master encryption key (if stored as a file) must be backed up separately from the database for security.

## Decision

The operator is responsible for backing up the SQLite database on the controller node. Podmander does not build in its own state backup mechanism.

The database location is documented prominently. The master key file should be backed up separately and securely.

## Consequences

### Positive

- No additional infrastructure or configuration — operators use tools they already know.
- Single-file backup is trivial with any backup tool.
- No Podmander-specific backup mechanism to implement, maintain, or debug.
- Operator retains full control over backup frequency, retention, and storage location.

### Negative

- Podmander cannot verify that backups exist or are current — the operator is solely responsible.
- New operators may not realize the database needs backing up until they lose it.
- The master key must be backed up separately (not alongside the database) for security — this is an easy step to miss.

### Neutral

- This decision applies only to the controller's state database. Volume backups on nodes are a separate concern (see [ADR-0029](0029-restic-and-native-send-for-backups.md)).

## Alternatives Considered

### Built-in backup to cloud storage

- Pros: Automatic, no operator action required.
- Cons: Adds cloud provider dependency (S3, GCS, etc.). Requires credential management. Duplicates functionality the operator likely already has. Increases Podmander's scope.
- Why rejected: Cloud provider dependency and scope creep. The database is one file — operators do not need purpose-built tooling for it.

### Replicated state across nodes

- Pros: Redundancy without operator backup management. Foundation for HA.
- Cons: Significant implementation complexity. The current architecture is single-controller (see [ADR-0001](0001-controller-agent-topology.md)). Replication is a future concern for HA, not for backup.
- Why rejected: Replication solves availability, not backup (both replicas could be corrupted). Proper backups are still needed. This is future HA work, not current scope.

## References

- [ADR-0003](0003-sqlite-for-controller-state.md) — SQLite for controller state storage
- [ADR-0021](0021-local-master-key-libsodium.md) — Local master key with libsodium encryption
- [ADR-0029](0029-restic-and-native-send-for-backups.md) — Restic and native send for volume backups (separate concern)
