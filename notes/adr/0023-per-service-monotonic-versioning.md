# ADR-0023: Per-Service Monotonic Versioning (Git-Revert Model)

**Status**: Accepted
**Date**: 2026-04-12

## Context

When deploys fail or introduce regressions, operators need to roll back to a known-good state. The versioning model determines how rollback works, what granularity it operates at, and how version history is structured.

Key forces:

- A failed API deploy should not require rolling back the database or other unrelated services.
- The target audience (small teams, solo admins) typically changes one service at a time.
- Version history must be linear and auditable — it should be possible to trace exactly what was deployed, when, and why.
- Rollback should create a new version (like `git revert`), not rewrite history (like restoring a backup). This preserves the audit trail.

## Decision

We will use per-service monotonic versioning. Version numbers always increase. Rollback creates a new version from a previous version's content — the history is linear and auditable.

Each deploy, rollback, or auto-repair creates a new version with:

- The service definition (TOML content)
- A source tag (`deploy`, `rollback`, `repair`)
- A lineage reference (for rollbacks: which version's content was used)
- An outcome (`succeeded`, `failed`, pending)

Podmander retains N versions per service (configurable, default 10).

Cluster-wide point-in-time rollback is available as "roll back all services to timestamp X" — this is implemented as per-service rollbacks, not a separate mechanism.

### What is versioned per service

- Image reference, environment variables, resource limits
- Port mappings, volume mounts, health check configuration
- Placement constraints

### What is not versioned

- Current placement decisions (operational, not declarative)
- Secrets (separate lifecycle via `podctl secret` commands)

## Consequences

### Positive

- Per-service granularity — roll back the API without affecting the database.
- Linear, auditable history — every version is numbered, traceable, and immutable.
- Rollback is just another deploy — no special recovery mode, uses the same deploy pipeline.
- Source and lineage tracking enables understanding *why* each version exists (was it a deploy, rollback, or auto-repair?).
- Cluster-wide rollback composes from per-service rollbacks — no separate mechanism needed.

### Negative

- Volume state is not rolled back with the service (database migrations are one-way). Rollback warnings are issued when relevant (see [ADR-0027](0027-snapshots-linked-to-versions.md) for volume snapshot integration).
- Version retention limits mean old versions are pruned — very old rollback targets may no longer be available.
- Rolling back during an in-progress deploy requires queuing — the current operation must complete or fail first.

### Neutral

- Failed versions are retained (not pruned) for forensic value.
- Rollback to a previously failed version is allowed with a warning — the failure may have been environmental.

## Alternatives Considered

### Cluster-wide snapshots

- Pros: Atomic rollback of the entire fleet to a point in time. Simpler mental model.
- Cons: A failed API deploy forces rolling back the database, Redis, and every other service. Wasteful and risky for changes that affect a single service (the common case for the target audience).
- Why rejected: Per-service is the common case. Cluster-wide rollback is available as a composed operation but should not be the default.

### Mutable version history (overwrite on rollback)

- Pros: Simpler — rollback restores version N, no new version created.
- Cons: Destroys audit trail. Cannot answer "what was running at time T?" Cannot distinguish between "deployed version 3" and "rolled back to version 3 after version 5 failed."
- Why rejected: Audit trail is critical for debugging production issues. The `git revert` model preserves history without additional complexity.

### Tag-based versioning (named versions instead of numbers)

- Pros: Human-readable labels ("v2.1-hotfix"), flexible naming.
- Cons: No natural ordering — "which version came before this one?" requires timestamps. Lineage tracking is harder. Operators must invent names for every deploy.
- Why rejected: Monotonic numbers provide natural ordering and lineage without naming overhead.

## References

- [ADR-0024](0024-infrastructure-component-versioning.md) — Infrastructure component versioning (same model)
- [ADR-0027](0027-snapshots-linked-to-versions.md) — Snapshots linked to service versions (volume rollback integration)
- [ADR-0005](0005-three-state-model.md) — Three-state model (versions represent desired→expected state transitions)
