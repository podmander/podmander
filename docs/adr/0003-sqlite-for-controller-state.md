# ADR-0003: SQLite for Controller State Storage

**Status**: Accepted
**Date**: 2026-04-12

## Context

The controller needs persistent storage for cluster state: service definitions, node metadata, version history, encrypted secrets, and the three state levels (desired, expected, actual). The storage must survive controller restarts and support future HA replication.

Key forces:

- The controller runs on a single node (initially). A database server would add operational burden for the target audience.
- State is modest in size — tens of services, tens of nodes, hundreds of versions.
- The operator must be able to back up state easily (see [ADR-0028](0028-operator-managed-state-backup.md)).
- Queries need to be expressive enough for version history, placement lookups, and state comparisons.

## Decision

We will use SQLite as the controller's state store. The database file lives on the controller node.

## Consequences

### Positive

- Zero operational overhead — no database server to install, configure, or maintain.
- Single-file storage is trivial to back up (copy the file, or use existing backup tools).
- ACID transactions protect against partial state updates during deploys.
- Excellent read performance for the modest data volumes involved.
- Well-supported across platforms with stable C API and Ada bindings available.

### Negative

- Single-writer limitation may become a bottleneck under HA with multiple controllers.
- No built-in replication — HA will require an external replication mechanism or a migration to a distributed store.
- Schema migrations need careful handling during Podmander upgrades.

### Neutral

- The operator is responsible for backing up the database file using their own tools (Time Machine, Restic, etc.).

## Alternatives Considered

### PostgreSQL / MySQL

- Pros: Built-in replication, proven at scale, rich query capabilities.
- Cons: Requires running a database server — significant operational overhead for the target audience (solo operators, small teams).
- Why rejected: Disproportionate operational complexity for the data volumes involved.

### Embedded key-value store (BoltDB, LMDB)

- Pros: Embedded like SQLite, good performance.
- Cons: No SQL query language — version history, placement queries, and state comparisons would require application-level indexing and query logic.
- Why rejected: Relational queries are a natural fit for the data model (services, versions, placements, nodes).

### Flat files (JSON/TOML)

- Pros: Human-readable, easy to inspect.
- Cons: No transactions, no query language, concurrent access is error-prone, poor performance for version history queries.
- Why rejected: Insufficient for the state management requirements.
