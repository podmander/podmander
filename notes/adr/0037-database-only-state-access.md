# ADR-0037: Database-Only State Access

**Date**: 2026-05-23
**Supersedes**: ADR-0035

## Context

ADR-0035 established a write-through cache pattern for the controller's state: every mutation goes to the database first, then updates an in-memory map. This was applied to agent state (`Agent_Maps.Map`).

We are now adding service deployment state (service versions, actual state). The question is whether to extend the write-through pattern to these new tables or use a different approach.

Key forces:

- The controller is a single-writer, single-threaded process. There is no concurrent writer that could change state between reads.
- The supervisor loop runs on a configurable interval (not every millisecond). SQLite read latency for local data is microseconds.
- Write-through caching requires every mutation path to update both the database and the in-memory map. Missing one creates a consistency bug that's hard to detect.
- The existing `Agent_Maps.Map` write-through pattern works but adds complexity — every agent state change must go through both the repository and the map.
- Future CLI access to state will need optimistic concurrency control (comparing version numbers). This is naturally expressed as database queries, not in-memory map operations.

## Decision

We will use the database as the single source of truth for all state. No in-memory caches. All reads go through the repository layer; all writes go through the repository layer. The in-memory `Agent_Maps.Map` on `Controller_Instance` will be removed.

The repository pattern from ADR-0035 (domain-driven operations like `Register`, `Touch`, `Set_State`) is retained. What changes is the removal of the write-through cache — repositories now read from and write to the database exclusively.

For safe concurrent access when the CLI is added later, we will use version comparison (optimistic concurrency control): each state row carries a version number, and updates include a "compare against expected version" check. If the current version differs, the write fails and the caller must re-read and retry.

## Consequences

### Positive

- Single source of truth — no possibility of cache/database divergence.
- Simpler code — no dual-write contract to maintain, no `Agent_Maps.Map` to keep in sync.
- Consistent pattern across all state tables (agents, services, actual state).
- Optimistic concurrency control is a natural fit for the version comparison the supervisor loop already needs.
- Easier to reason about — the database is always authoritative.

### Negative

- Every state read hits the database. For the MVP scale (tens of agents, tens of services), this is negligible (microsecond local reads).
- The supervisor loop must issue database queries instead of in-memory lookups. This is acceptable given the configurable interval and local SQLite performance.

### Neutral

- The `Controller_Instance` record loses its `Agents` field. The controller reads agent state from the database when needed.
- The repository pattern (domain-driven operations) is unchanged. Only the caching layer is removed.

## Alternatives Considered

### Write-through cache (ADR-0035 original)

- Pros: Fast in-memory lookups for the supervisor loop. No database reads on the hot path.
- Cons: Dual-write contract must be maintained on every mutation path. Cache/database divergence bugs are hard to detect. Inconsistent pattern if new state tables don't get cached.
- Why superseded: The consistency cost outweighs the performance benefit at MVP scale. The controller is single-threaded; there is no concurrent access risk that a cache would mitigate.

### Read-through cache (lazy loading from database)

- Pros: Avoids the dual-write contract — reads populate the cache, writes invalidate it.
- Cons: Cache invalidation is still a contract that must be maintained. Adds complexity for marginal benefit at MVP scale.
- Why rejected: Same reasoning as write-through — the simplicity of database-only access is more valuable than cache performance at this scale.

## References

- [ADR-0003: SQLite for Controller State Storage](0003-sqlite-for-controller-state.md)
- [ADR-0005: Three-State Model](0005-three-state-model.md)
- [ADR-0006: Continuous Supervisor Loop](0006-continuous-supervisor-loop.md)
- [ADR-0035: Database Layer Design](0035-database-layer-design.md) (superseded)
- [ADR-0038: State Tracking Design for MVP](0038-state-tracking-design.md)