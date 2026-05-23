# ADR-0038: State Tracking Design for MVP

**Date**: 2026-05-23

## Context

ADR-0005 defines a three-state model (Desired, Expected, Actual). ADR-0006 defines a continuous supervisor loop that compares expected vs actual state and acts on divergence. The current prototype can deploy a service to an agent but has no state persistence — deploy results are logged and discarded.

We need to design the state types and data flow that will replace the one-shot `Pending_Deploy` mechanism with a persistent state pipeline. This ADR covers the MVP scope; the full three-state model is deferred until the scheduler is implemented.

Key forces:

- The MVP is a "Podman remote" — deploy a service to a connected agent, not a full orchestrator.
- Placement is trivial for MVP (deploy to the connected agent). No scheduler needed yet.
- The controller is a single-writer, single-threaded process. No concurrent access risk.
- ADR-0037 establishes database-only state access (no in-memory caches).

## Decision

### 1. Three-state model simplified for MVP

The full three-state model (Desired, Expected, Actual) collapses for MVP:

| Concept | MVP | Full model |
|---|---|---|
| Desired State | Implicit: latest Service Version per service | Same + placement rules |
| Expected State | Collapsed into Desired State | Scheduler output: (service, version, node) |
| Actual State | (service, version, node) — version only | (service, version, node, runtime status) |

The fundamental comparison is always Desired vs Actual. Expected State becomes a separate layer when the scheduler is implemented. For MVP, since placement is trivial (deploy to the connected agent), there is nothing for the scheduler to decide — Desired State directly determines what should be on each node.

### 2. Service Version as immutable ASD snapshot

A Service Version is an immutable snapshot of the Abstract Service Definition (ASD) — the structured representation of a service's configuration (image, environment variables, ports, volumes). Each `podctl deploy` that changes a service creates a new version with a monotonic version number. Rollback creates a new version with content from a previous version (like `git revert`).

The quadlet is a derived artifact rendered on demand from the ASD. It is not stored in the Service Version.

Service Versions are stored as full snapshots (not diffs). The ASD is small (a few hundred bytes); at 10 versions per service and 50 services, storage is negligible. Full snapshots make comparison and debugging simple.

### 3. Desired State is implicit

For MVP, "desired state" for a service is simply "the latest Service Version." There is no separate Desired State table. When the operator deploys a new TOML, a new Service Version is created, and it becomes the desired state by virtue of being the latest.

This means the supervisor loop's comparison is: "Is the actual version on this node the same as the latest Service Version for this service? If not, catch up."

### 4. Actual State is sparse

Actual State stores only entries for services that exist on a node. There are no NOT_PRESENT rows — absence of an entry means the service is not deployed on that node. The supervisor detects drift by comparing Expected State keys against Actual State keys.

### 5. Actual State updated on Deploy_Result

For MVP, Actual State is updated when the agent sends back a `Deploy_Result` confirming that a deployment landed. This is the ACK signal that confirms the desired state has been reached.

Heartbeat-based status reporting (RUNNING, STOPPED, DEPLOY_FAILED, etc.) is a later feature. When agents report service-level status, Actual State gains a runtime status column.

### 6. Database schema

```sql
CREATE TABLE IF NOT EXISTS service_versions (
    service_name  TEXT NOT NULL,
    version       INTEGER NOT NULL,
    image         TEXT NOT NULL,
    env           TEXT NOT NULL,      -- JSON-serialized Env_Array
    ports         TEXT NOT NULL,      -- JSON-serialized Port_Array
    volumes       TEXT NOT NULL,      -- JSON-serialized Volume_Array
    description   TEXT NOT NULL DEFAULT '',
    wanted_by     TEXT NOT NULL DEFAULT '',
    created_at    TEXT NOT NULL,      -- ISO 8601 UTC
    PRIMARY KEY (service_name, version)
);

CREATE TABLE IF NOT EXISTS actual_state (
    service_name  TEXT NOT NULL,
    node_id       TEXT NOT NULL,
    version       INTEGER NOT NULL,
    updated_at    TEXT NOT NULL,      -- ISO 8601 UTC
    PRIMARY KEY (service_name, node_id),
    FOREIGN KEY (service_name, version) REFERENCES service_versions(service_name, version)
);
```

Complex ASD fields (env, ports, volumes) are stored as JSON strings. They are small and rarely queried independently. Normalization can be added later if query patterns demand it.

### 7. Ada types

```ada
--  Service Version: an immutable snapshot of a service's ASD
type Service_Version is record
   Service_Name : Unbounded_String;
   Version      : Positive;
   Image        : Unbounded_String;
   Env          : Env_Array (1 .. MAX_ENV_ENTRIES);
   Env_Count    : Natural := 0;
   Ports        : Port_Array (1 .. MAX_PORTS_ENTRIES);
   Ports_Count  : Natural := 0;
   Volumes      : Volume_Array (1 .. MAX_VOLUMES_ENTRIES);
   Volumes_Count : Natural := 0;
   Description  : Unbounded_String;
   Wanted_By    : Unbounded_String;
   Created_At   : Ada.Calendar.Time;
end record;

--  Key for actual state lookups: (service_name, node_id)
type Service_Node_Key is record
   Service_Name : Unbounded_String;
   Node_Id      : Unbounded_String;
end record;

--  Actual state entry: what version is deployed on which node
type Actual_State_Entry is record
   Service_Name : Unbounded_String;
   Node_Id      : Unbounded_String;
   Version      : Positive;
   Updated_At   : Ada.Calendar.Time;
end record;
```

`Service_Version` is a separate type from `Service_Definition` (the parser output). They share fields now but will diverge — `Service_Version` is a storage type with versioning metadata; `Service_Definition` is an input type from TOML parsing.

### 8. MVP flow

```
TOML → parser → Service_Definition (ASD)
                        ↓
              Service_Version (persisted to service_versions table)
                        ↓
Supervisor loop: latest version per service vs. actual_state
                        ↓
        version mismatch → render quadlet from ASD → Deploy_Command → Agent
                        ↓
        Deploy_Result → update actual_state
```

The `Pending_Deploy` mechanism is replaced entirely. The supervisor loop determines what needs deploying by comparing desired state (latest Service Version) against actual state (what's on each node).

### 9. Stacks deferred

The Stack concept (grouping related services) is deferred for MVP. A Service Version can exist without a Stack reference. When Stacks are added, a `stack_name` column is added to `service_versions` and a `stacks` table is created.

## Consequences

### Positive

- Clear state pipeline replaces the one-shot `Pending_Deploy` mechanism.
- Service Versions provide immutable history and enable rollback.
- Database as single source of truth (ADR-0037) — no cache synchronization issues.
- The MVP flow is simple: version comparison determines what needs deploying.
- The full three-state model (ADR-0005) is the target architecture; MVP is a proper subset, not a detour.

### Negative

- No runtime status in Actual State yet — the supervisor can only detect version mismatches, not service crashes. This is acceptable for MVP (a "Podman remote") but must be added before production use.
- JSON serialization of ASD fields (env, ports, volumes) is not queryable in SQL. Acceptable at MVP scale; normalize later if needed.
- No placement logic — all services deploy to the connected agent. The scheduler is a prerequisite for multi-node deployments.

### Neutral

- The `Pending_Deploy` type and `Check_Test_Deploy` procedure will be removed from `Controller_Instance`.
- The `Agent_Maps.Map` on `Controller_Instance` will be removed (ADR-0037).

## Alternatives Considered

### Store quadlet content in Service Version

- Pros: Simpler deploy — just send the stored quadlet.
- Cons: Quadlet is a derived artifact that loses information (placement rules, environment context). Cannot re-render for different nodes. Cannot diff versions at the definition level.
- Why rejected: The ASD is the source of truth; the quadlet is rendered on demand.

### Separate Desired State table for MVP

- Pros: Explicit representation of "which version should be active."
- Cons: For MVP, desired state is simply "the latest version." A separate table would be a pointer to the latest version with no additional information. Adds complexity without value.
- Why rejected: The latest Service Version per service is the desired state. A separate table can be added when placement rules or version pinning are needed.

### Include runtime status in Actual State for MVP

- Pros: Full visibility from day one.
- Cons: Requires agents to report service-level status in heartbeats, which is not implemented yet. Would block the state pipeline on the agent reporting feature.
- Why rejected: MVP scope is the state pipeline. Runtime status is added when agents report it.

## References

- [ADR-0003: SQLite for Controller State Storage](0003-sqlite-for-controller-state.md)
- [ADR-0005: Three-State Model](0005-three-state-model.md)
- [ADR-0006: Continuous Supervisor Loop](0006-continuous-supervisor-loop.md)
- [ADR-0037: Database-Only State Access](0037-database-only-state-access.md)