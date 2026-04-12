# ADR-0027: Snapshots Linked to Service Versions

**Status**: Accepted
**Date**: 2026-04-12

## Context

Service rollback (see [ADR-0023](0023-per-service-monotonic-versioning.md)) restores the previous service definition — image, config, environment variables. But application state lives in volumes. Rolling back code without considering data state can cause inconsistencies (e.g., code expecting schema v1 running against a database migrated to schema v2).

Key forces:

- Volume snapshots taken at deploy time capture the data state *before* a service version was applied. This creates a natural pairing between "code version N" and "data state before N."
- Not all volumes support snapshots (see [ADR-0025](0025-filesystem-driver-abstraction.md)) — the mechanism must degrade gracefully.
- Volume rollback is inherently more dangerous than code rollback (data loss is possible). It must be interactive and explicit.
- Snapshot retention should follow a clear policy — deploy snapshots should be pruned automatically, but forensic and manual snapshots should be preserved.

## Decision

Volume snapshots are linked to service versions in the database. When a service is deployed and the volume has `snapshots.on_deploy = true`, Podmander creates a read-only snapshot before applying the new version and records the link.

During rollback, Podmander checks for associated volume snapshots and offers interactive rollback:

1. If a snapshot exists for the target version: prompt the operator to roll back the volume.
2. If the operator declines: warn that data may be inconsistent, proceed with code-only rollback.
3. If no snapshot exists: warn and proceed with code-only rollback.

### Snapshot pruning

Pruning respects the retention count and never deletes snapshots linked to:

- The currently active service version
- Any failed service version (forensic value)
- Manual snapshots (explicit operator intent)

Backup snapshots follow their own retention policy.

## Consequences

### Positive

- Transforms rollback from "code only" to "code plus data state" when snapshot-capable volumes are used.
- Deploy-time snapshots are automatic (opt-in per volume) — operators get rollback capability without manual snapshot management.
- Interactive rollback prompts prevent accidental data loss — the operator explicitly chooses whether to roll back data.
- Snapshot-to-version linking enables forensic analysis — "what was the data state when version N was deployed?"

### Negative

- Deploy-time snapshots add latency to deploys (typically small — BTRFS/ZFS snapshots are fast).
- Volume rollback causes downtime — services must be stopped, volume rolled back, services restarted.
- Database migrations are inherently one-directional. Rolling back both code and data to pre-migration state may result in data loss (rows added after the migration are lost). Warnings are issued.

### Neutral

- `directory` driver volumes cannot participate in snapshot linking — they silently skip snapshot creation.
- Multiple services sharing a volume trigger a snapshot on any dependent service's deploy.

## Alternatives Considered

### No snapshot-to-version linking (manual snapshots only)

- Pros: Simpler — operators manage snapshots independently of service versions.
- Cons: No automated deploy-time snapshots. Operators must remember to snapshot before each deploy. No connection between code versions and data state in the database.
- Why rejected: Manual snapshot management is error-prone. The linking enables automated "code plus data" rollback, which is a significant usability improvement.

### Automatic volume rollback (no interactive prompt)

- Pros: Simpler rollback flow — one command rolls back everything.
- Cons: Automatic data rollback is dangerous — data written after the snapshot is lost without warning. Database migrations, user uploads, and log data would vanish.
- Why rejected: Data loss must always be an explicit, informed operator decision.

### Separate volume versioning (independent from service versions)

- Pros: Volumes have their own version history, independent of services.
- Cons: Loses the connection between code state and data state. Operators must manually correlate "which volume snapshot corresponds to service version 4?"
- Why rejected: The whole point of linking is to answer "what data state matches this code version?" automatically.

## References

- [ADR-0023](0023-per-service-monotonic-versioning.md) — Per-service monotonic versioning
- [ADR-0025](0025-filesystem-driver-abstraction.md) — Filesystem driver abstraction
- [ADR-0026](0026-btrfs-default-zfs-optional.md) — BTRFS as recommended default
