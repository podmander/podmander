# ADR-0038: State Tracking Design for MVP

**Date**: 2026-05-23
**Amended**: 2026-05-24 — Replaced `failed` boolean with `Catalog_Entry_State` enum (Pending, In_Progress, Failed, Deployed) to prevent duplicate deploys.

## Context

ADR-0005 defines a three-state model (Desired, Expected, Actual). ADR-0006 defines a continuous supervisor loop that compares expected vs actual state and acts on divergence. The current prototype can deploy a service to an agent but has no state persistence — deploy results are logged and discarded.

We need to design the state types and data flow that will replace the one-shot `Pending_Deploy` mechanism with a persistent state pipeline. This ADR covers the MVP scope; the full three-state model is deferred until the scheduler is implemented.

Key forces:

- The MVP is a "Podman remote" — deploy a service to a connected agent, not a full orchestrator.
- Placement is trivial for MVP (deploy to the connected agent). No scheduler needed yet.
- The controller is a single-writer, single-threaded process. No concurrent access risk.
- ADR-0037 establishes database-only state access (no in-memory caches).
- The original design used separate `actual_state` and `service_versions` tables, but this created a gap: the supervisor loop could detect version mismatches for deployed services but could not discover brand-new services that had no `actual_state` entry. A unified Service Catalog solves this by making "not deployed" an explicit state (`current_version = 0`) rather than an absent row.

## Decision

### 1. Service Catalog replaces separate desired/actual state

The full three-state model (Desired, Expected, Actual) collapses for MVP into a single Service Catalog:

| Concept | MVP | Full model |
|---|---|---|
| Desired State | Service Catalog `target_version` | Same + placement rules |
| Expected State | Collapsed into target_version | Scheduler output: (service, version, node) |
| Actual State | Service Catalog `current_version` | (service, version, node, runtime status) |

The Service Catalog is the single source of truth for both "what should be" and "what is." Each entry tracks a service's deployment intent and status on a specific node. The supervisor loop's comparison is trivial: `current_version ≠ target_version` means action is needed.

### 2. Pipeline: Parser → Registrar → Scheduler → Supervisor

The deploy flow is a pipeline of single-responsibility objects:

```
TOML → [Parser] → Service_Definition (ASD)
                         ↓
               [Registrar] → services row (if new) + service_versions row
                         ↓
                [Scheduler] → service_catalog row (agent_id or NULL)
                         ↓
               [Supervisor] → schedule unscheduled entries
                            → reconcile current ≠ target, not failed
                            → send Deploy_Command with catalog_id
                         ↓
               [Deploy_Result handler] → update catalog by catalog_id
```

- **Parser**: Converts TOML to a Service_Definition (ASD). Unchanged from current implementation.
- **Registrar**: Creates a `services` row (if the service is new) and a `service_versions` row. Implicit service creation on first deploy — no separate "register service" command needed.
- **Scheduler**: Creates or updates a `service_catalog` entry, assigning an agent. For MVP, always assigns the single connected agent or leaves `agent_id = NULL` if no agent is connected.

- **Supervisor**: Two jobs per iteration: (1) schedule any catalog entries with `agent_id IS NULL`, (2) deploy any entries where `current_version ≠ target_version AND failed = 0`.
### 3. Service Version as immutable ASD snapshot

A Service Version is an immutable snapshot of the Abstract Service Definition (ASD) — the structured representation of a service's configuration (image, environment variables, ports, volumes). Each deploy that changes a service creates a new version with a monotonic version number. Rollback creates a new version with content from a previous version (like `git revert`).

The quadlet is a derived artifact rendered on demand from the ASD. It is not stored in the Service Version.

Service Versions are stored as full snapshots (not diffs). The ASD is small (a few hundred bytes); at 10 versions per service and 50 services, storage is negligible.

### 4. Services table

A `services` table provides a canonical entity for each named service. The Registrar creates a row implicitly on first deploy. The table uses a surrogate primary key; `name` has a unique index for lookups.

```sql
CREATE TABLE IF NOT EXISTS services (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);
```

### 5. Database schema

```sql
CREATE TABLE IF NOT EXISTS services (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS service_versions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    service_id   INTEGER NOT NULL,
    version      INTEGER NOT NULL,
    image        TEXT NOT NULL,
    env          TEXT NOT NULL,      -- JSON-serialized Env_Array
    ports        TEXT NOT NULL,      -- JSON-serialized Port_Array
    volumes      TEXT NOT NULL,      -- JSON-serialized Volume_Array
    description  TEXT NOT NULL DEFAULT '',
    wanted_by    TEXT NOT NULL DEFAULT '',
    created_at   TEXT NOT NULL,      -- ISO 8601 UTC
    FOREIGN KEY (service_id) REFERENCES services(id),
    UNIQUE (service_id, version)
);

CREATE TABLE IF NOT EXISTS service_catalog (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    service_id      INTEGER NOT NULL,
    agent_id        INTEGER REFERENCES agents(id), -- NULL = unscheduled

    ...

    ON service_catalog(service_id, agent_id)

    WHERE agent_id IS NOT NULL;
```

Key design points:

- `current_version = 0` means "not deployed." No foreign key constraint on this column (0 doesn't exist in `service_versions`).
- `target_version` always references a real `service_versions` row. The scheduler sets it when creating or updating the catalog entry.
- `state` is a `Catalog_Entry_State` enum stored as an integer: Pending (0) = needs deployment, In_Progress (1) = deploy command sent awaiting result, Failed (2) = deploy failed, Deployed (3) = current_version matches target_version. The supervisor only picks up entries in Pending state, preventing duplicate deploys. `Set_Target` resets state to Pending (retrigger). On controller startup, any In_Progress entries are reset to Pending (stale from crash).
- `agent_id = NULL` means "not yet scheduled." The supervisor calls the scheduler to assign an agent when it finds unscheduled entries.
- The unique index on `(service_id, agent_id)` only applies when `agent_id IS NOT NULL`. Multiple NULL rows for the same service are prevented at the application level.
- `agent_id` is `INTEGER REFERENCES agents(id)` (nullable). Issue #79 replaced the TEXT node_id with this integer FK.

Complex ASD fields (env, ports, volumes) are stored as JSON strings. They are small and rarely queried independently. Normalization can be added later if query patterns demand it.

### 6. catalog_id as opaque correlation token

Every `Deploy_Command` carries a `catalog_id` — the primary key of the Service Catalog entry. The agent treats it as opaque and echoes it back in the `Deploy_Result`. The controller uses it to look up the catalog entry directly, avoiding (service_name, node_id) lookups.

### 7. Supervisor loop behavior

The supervisor loop runs on each iteration:

1. **Schedule**: Find catalog entries where `agent_id IS NULL`. Call the scheduler to assign an agent (or leave NULL if no agent is connected).
2. **Reconcile**: Find catalog entries where `state = Pending` (0). Render the quadlet from the ASD, send a `Deploy_Command` with the entry's `catalog_id`, and set `state = In_Progress`.

On `Deploy_Result`:
- **Success**: Set `current_version = target_version`, `state = Deployed`, update `updated_at`.
- **Failure**: Set `state = Failed`, update `updated_at`. `current_version` stays unchanged.

### 8. --test-config is temporary

The `--test-config` CLI flag triggers the Parser → Registrar → Scheduler pipeline at startup. It will be removed when `podctl deploy` is implemented. The controller no longer exits after a test deploy — it runs until interrupted, and the supervisor loop handles convergence.

### 9. Stacks deferred

The Stack concept (grouping related services) is deferred for MVP. A Service Version can exist without a Stack reference. When Stacks are added, a `stack_name` column is added to `service_versions` and a `stacks` table is created.

## Consequences

### Positive

- Service Catalog is the single source of truth for both intent and reality. No separate desired-state and actual-state tables to keep consistent.
- New services are visible by construction: `current_version = 0` in the catalog. No extra query needed to discover "services that exist but aren't deployed."
- The supervisor loop is trivial: compare two integers, act on mismatch. No complex state derivation.
- The pipeline (Parser → Registrar → Scheduler → Supervisor) has clear single-responsibility boundaries.
- `Pending_Deploy` mechanism is eliminated entirely. The catalog and supervisor handle everything uniformly.
- `--test-config` one-shot exit behavior is eliminated. The controller always runs until interrupted.
- Database as single source of truth (ADR-0037) — no cache synchronization issues.
- The full three-state model (ADR-0005) is the target architecture; MVP is a proper subset, not a detour.

### Negative

- No runtime status in Service Catalog yet — the supervisor can only detect version mismatches, not service crashes. This is acceptable for MVP (a "Podman remote") but must be added before production use.
- JSON serialization of ASD fields (env, ports, volumes) is not queryable in SQL. Acceptable at MVP scale; normalize later if needed.
- No placement logic — all services deploy to the connected agent. The scheduler is a prerequisite for multi-node deployments.
- `agent_id` is `INTEGER REFERENCES agents(id)`. Issue #79 replaced the TEXT node_id with this integer FK.
- Application-level enforcement is needed for "only one NULL row per service" in the catalog (the unique index only covers non-NULL agent_ids).

### Neutral

- The `Pending_Deploy` type, `Check_Test_Deploy` procedure, and `Test_Deploy` field on `Controller_Instance` will be removed.
- The `actual_state` table and repository will be removed, replaced by `service_catalog`.
- The `Agent_Maps.Map` on `Controller_Instance` will be removed (ADR-0037).

## Alternatives Considered

### Separate actual_state table (original design)

- Pros: Matches the three-state model directly. Each state has its own table.
- Cons: The supervisor loop cannot discover new services — services with no `actual_state` entry are invisible. Requires an additional query to find "services that exist but aren't deployed." The catalog model makes this case explicit (`current_version = 0`).
- Why rejected: The catalog model is simpler and solves the "new service discovery" problem by construction.

### Separate Desired State table for MVP

- Pros: Explicit representation of "which version should be active."
- Cons: For MVP, desired state is simply "the latest version." A separate table would be a pointer to the latest version with no additional information. The catalog's `target_version` column serves this purpose.
- Why rejected: The catalog's `target_version` is the desired state. A separate table can be added when placement rules or version pinning are needed.

### Include runtime status in Service Catalog for MVP

- Pros: Full visibility from day one.
- Cons: Requires agents to report service-level status in heartbeats, which is not implemented yet. Would block the state pipeline on the agent reporting feature.
- Why rejected: MVP scope is the state pipeline. Runtime status is added when agents report it.

### Store quadlet content in Service Version

- Pros: Simpler deploy — just send the stored quadlet.
- Cons: Quadlet is a derived artifact that loses information (placement rules, environment context). Cannot re-render for different nodes. Cannot diff versions at the definition level.
- Why rejected: The ASD is the source of truth; the quadlet is rendered on demand.

## References

- [ADR-0003: SQLite for Controller State Storage](0003-sqlite-for-controller-state.md)
- [ADR-0005: Three-State Model](0005-three-state-model.md)
- [ADR-0006: Continuous Supervisor Loop](0006-continuous-supervisor-loop.md)
- [ADR-0023: Per-Service Monotonic Versioning](0023-per-service-monotonic-versioning.md)
- [ADR-0037: Database-Only State Access](0037-database-only-state-access.md)
- [Issue #79: Replace node_id TEXT with integer FK (resolved)](https://code.monospacementor.com/podmander/podmander/issues/79)