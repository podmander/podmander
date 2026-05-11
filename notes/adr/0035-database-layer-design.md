# ADR-0035: Database Layer Design

**Status**: Proposed
**Date**: 2026-05-11

## Context

ADR-0003 selected SQLite as the controller's persistent store. ADR-0005 defined three state levels (desired, expected, actual). The `ada_sqlite3` binding (~0.1.1) is already declared as a dependency. The current controller tracks agents in an in-memory `Agent_Maps.Map` with no persistence across restarts.

We need to design the database layer: how the schema is created and migrated, what the agents table looks like, what the persistence API surface is, how in-memory and persistent state stay consistent, and how the controller initializes from the database on startup.

Key forces:

- The controller is a single-writer process (ADR-0003 notes the single-writer limitation as acceptable for MVP).
- Schema will evolve as features are added (services, secrets, infrastructure configs). Migrations must be safe and repeatable.
- The in-memory `Agent_Maps.Map` provides fast lookup for the supervisor loop. The database provides durability. These must stay consistent.
- Startup must be fast: load agents from DB, then reconcile with live heartbeats.
- The `ada_sqlite3` library provides `Database` (tagged, limited, controlled) with `Open`/`Close`, `Execute` for DDL/DML, `Prepare`/`Step`/`Bind_*`/`Column_*` for parameterized queries, and `SQLite_Error` exception for error handling. No built-in migration support.

## Decision

### 1. Package structure: Repository pattern alongside domain

Each entity's persistence lives in a `Repository` child package alongside its domain logic, not centralized under a `Database` package. This follows the Repository pattern common in Go and Rust projects that avoid ORMs: per-entity data access modules sit next to the entity they serve, while cross-cutting concerns (connection lifecycle, migrations) stay centralized.

```
Podmander.Controller.Database              -- DB_Handle, Open, Close, Migrations
Podmander.Controller.Agent.Repository      -- Register, Touch, Set_State, Load_All, Remove
Podmander.Controller.Service.Repository    -- (future) Deploy, Archive, Load_All
Podmander.Controller.Secret.Repository     -- (future) Store, Rotate_Key, Retrieve
```

The `Database` package owns the `DB_Handle` (wrapping `Ada_Sqlite3.Database`) and exposes it to the `Repository` packages. Each `Repository` package provides domain-driven operations — not generic CRUD — named after the business events that trigger them (e.g., `Register`, `Touch`, `Set_State`).

Why this over a centralized `Database.Agents` / `Database.Services` structure:

- As the data layer grows, entity-specific persistence is tightly coupled to its domain logic. Keeping them adjacent makes the relationship obvious and reduces navigation friction.
- Migrations are cross-cutting (a single migration often touches multiple tables) and belong in `Database.Migrations`, separate from per-entity operations.
- Each entity subtree (`Agent`, `Service`, `Secret`) can grow its own domain logic alongside its repository without bloating a central package.
- This matches the Repository pattern used in Go (`internal/repository/user_repo.go`) and Rust (`src/repositories/user_repository.rs`) projects without ORMs.

### 2. Migration approach: sequential numbered scripts

We use a `schema_version` table to track the current migration level. On startup, `Initialize` reads the current version and applies any pending migrations in order. Each migration is a named constant SQL string in the `Migrations` package, identified by number (1, 2, 3, ...).

```ada
--  In Podmander.Controller.Database.Migrations
type Migration is record
   Version : Positive;
   SQL     : Ada.Strings.Unbounded.Unbounded_String;
end record;

Migration_History : constant array (Positive range <>) of Migration :=
  [1 => (Version => 1, SQL => To_Unbounded_String (Migration_001_SQL)),
   2 => (Version => 2, SQL => To_Unbounded_String (Migration_002_SQL)),
   ...];
```

Migrations run inside a transaction. If any migration fails, the transaction rolls back and the controller fails to start with a clear error. Migrations are idempotent within a version (use `CREATE TABLE IF NOT EXISTS`, etc.) to handle re-execution after a partial startup.

The initial migration creates the `schema_version` table and the `agents` table (see schema below). Future migrations add services, secrets, infrastructure configs, and the three-state tables.

### 3. Agents table schema

```sql
CREATE TABLE IF NOT EXISTS agents (
    name       TEXT PRIMARY KEY,
    node_id    TEXT NOT NULL,
    state      TEXT NOT NULL CHECK (state IN ('registered', 'unresponsive', 'lost')),
    last_seen  TEXT NOT NULL  -- ISO 8601 UTC timestamp
);
```

Rationale:

- `name` is the natural key (agent names are unique per cluster, set during enrollment).
- `state` uses a `CHECK` constraint to enforce valid `Agent_State` values at the database level.
- `last_seen` is stored as ISO 8601 text because SQLite has no native datetime type and `ada_sqlite3` provides `Column_Text`/`Bind_Text` for string I/O. The controller converts between `Ada.Calendar.Time` and ISO 8601 at the API boundary.
- No `id` surrogate key — agent name is already unique and meaningful. Adding a surrogate key would require a join on every query for no benefit at this scale.

### 4. Domain-driven API (not CRUD)

Each entity's `Repository` child package provides operations named after the domain events that trigger them, not generic CRUD verbs. This avoids an explosion of `Insert_*`/`Update_*`/`Delete_*` procedures and keeps the API vocabulary close to the controller's domain language.

```ada
--  Podmander.Controller.Database — connection lifecycle only
package Podmander.Controller.Database is

   Database_Error : exception;
   --  Raised on any unrecoverable database operation failure.

   type DB_Handle is limited private;
   --  Opaque handle wrapping the SQLite connection.
   --  Controlled: closing the database finalizes all prepared statements
   --  and closes the connection automatically.

   procedure Open
     (Handle : out DB_Handle;
      Path   : String);
   --  Open (or create) the database at Path, run pending migrations,
   --  and prepare cached statements. Raises Database_Error on failure.

   procedure Close (Handle : in out DB_Handle);
   --  Close the database connection. Safe to call multiple times.

private
   type DB_Handle is limited record
      DB : Ada_Sqlite3.Database;
   end record;
end Podmander.Controller.Database;

--  Podmander.Controller.Agent.Repository — agent persistence
with Podmander.Controller.Database;
with Podmander.Types;

package Podmander.Controller.Agent.Repository is

   procedure Register
     (DB    : DB_Handle;
      Agent : Podmander.Types.Agent_Info);
   --  Persist a newly enrolled agent. Raises Database_Error if an agent
   --  with the same name already exists (UNIQUE constraint violation).

   procedure Touch
     (DB      : DB_Handle;
      Name    : String;
      Seen_At : Ada.Calendar.Time);
   --  Update an agent's last_seen timestamp. Called on each heartbeat.
   --  Raises Database_Error if the agent does not exist.

   procedure Set_State
     (DB    : DB_Handle;
      Name  : String;
      State : Podmander.Types.Agent_State);
   --  Update an agent's connection state. Called when the supervisor loop
   --  detects a timeout or when an agent reconnects.
   --  Raises Database_Error if the agent does not exist.

   function Load_All (DB : DB_Handle) return Agent_Maps.Map;
   --  Return all persisted agents as an in-memory map. Used at startup
   --  to populate the controller's Agent_Maps.Map.

   procedure Remove
     (DB   : DB_Handle;
      Name : String);
   --  Remove an agent from the database. No-op if the agent does not exist.

end Podmander.Controller.Agent.Repository;
```

Why domain-driven operations instead of CRUD:

- The controller never says "insert an agent" — it says "an agent enrolled." `Register` captures that intent.
- The controller never says "update an agent" — it says "the agent sent a heartbeat" (`Touch`) or "the agent timed out" (`Set_State`). These are different operations with different SQL and different error semantics.
- When we add `Service` or `Secret`, each gets its own `Repository` child package with its own domain vocabulary (`Deploy`, `Rotate_Key`, `Archive`) rather than a mechanical `Insert`/`Update`/`Delete` set.
- The `Database` package stays small — just `Open`, `Close`, and the `DB_Handle` type.

Error handling strategy:

- All database errors are caught and re-raised as `Database_Error` with the original SQLite error message. This keeps the controller's error handling uniform and avoids leaking `ada_sqlite3` exceptions outside the `Database` and `Repository` packages.
- Expected "not found" conditions (e.g., `Touch` with a nonexistent agent name) raise `Database_Error` — the caller should ensure the agent exists before calling, or handle the exception. This is consistent with Ada's convention that operations raise exceptions on failure.

### 5. State sync strategy: write-through cache

The in-memory `Agent_Maps.Map` acts as a write-through cache over the database. Every mutation goes to the database first, then updates the in-memory map.

Pattern for each mutation:

```ada
--  Example: marking an agent as unresponsive after timeout
procedure Mark_Unresponsive
  (Self  : in out Controller_Instance;
   Name  : String) is
begin
   Agent.Repository.Set_State (Self.DB, Name, Unresponsive);  --  1. Persist
   declare
      Info : Agent_Info := Self.Agents.Element (Name);
   begin
      Info.State := Unresponsive;                              --  2. Update memory
      Self.Agents.Replace (Name, Info);
   end;
end Mark_Unresponsive;
```

Why write-through (not write-behind):

- The database is local (SQLite on the same host). Write latency is negligible (microseconds).
- Write-through guarantees that if the controller crashes, the database always reflects the last confirmed state. No data loss.
- Write-behind would require a flush-on-shutdown path and a reconciliation path for unflushed writes after a crash — complexity that isn't justified for microsecond-latency local writes.

The `Controller_Instance` record gains a `DB_Handle` field:

```ada
type Controller_Instance is tagged limited record
   Config      : Controller_Config;
   Certificate : CZMQ.Certificates.Certificate;
   Socket      : CZMQ.Sockets.Socket;
   Agents      : Agent_Maps.Map;
   DB          : Database.DB_Handle;  --  New field
   Running     : Boolean := False;
end record;
```

### 6. Startup behavior

`Make_Listening_Controller` gains a database initialization step:

1. Call `Database.Open (DB, Path)` where `Path` comes from the controller config (default: `~/.local/share/podmander/state.db`).
2. `Database.Open` runs pending migrations (creating tables if fresh).
3. Call `Agent.Repository.Load_All` to load all persisted agents into `Self.Agents`.
4. The supervisor loop begins. Agents that were `Registered` or `Unresponsive` in the database start as `Unresponsive` — they must send a heartbeat to prove they're still alive. Agents that were `Lost` stay `Lost`.

This means:

- After a controller restart, no agent is considered `Registered` until it sends a heartbeat. This is correct because the controller can't know whether an agent survived the controller's downtime.
- The `Check_Timeouts` procedure will transition `Unresponsive` agents to `Lost` after the normal timeout, which handles the case where an agent never reconnects.

### 7. Shutdown behavior

`Close` is called on the `DB_Handle` during controller shutdown. Because `DB_Handle` wraps a controlled `Ada_Sqlite3.Database`, the connection is also closed automatically if the controller crashes without a clean shutdown. SQLite's WAL mode (enabled via `PRAGMA journal_mode=WAL` in the initial migration) ensures crash recovery.

## Consequences

### Positive

- Persistent agent state survives controller restarts. No re-enrollment needed after a bounce.
- Write-through caching gives both durability and fast in-memory lookups for the supervisor loop.
- Numbered migrations provide a clear upgrade path. Adding services, secrets, and three-state tables is straightforward.
- `CHECK` constraints enforce data integrity at the database level, catching bugs that bypass Ada-level validation.
- Domain-driven operations in `Repository` packages keep the API vocabulary close to the controller's business logic. Each entity subtree (`Agent`, `Service`, `Secret`) can grow its own domain logic alongside its repository without bloating a central package.
- The `Database` package encapsulates connection lifecycle and migrations. The `Repository` packages encapsulate per-entity SQL. The controller only sees `DB_Handle` and domain operations — no SQL leaks out.

### Negative

- Every agent state change now involves a database write. For the MVP scale (tens of agents), this is negligible. If scale grows, a write-behind batch strategy could be added later.
- Two sources of truth (memory + database) must stay in sync. The write-through pattern makes this straightforward, but it's still a contract that must be maintained.
- ISO 8601 text timestamps in SQLite require conversion at every API boundary. A small utility package for `Time ↔ String` conversion will be needed.

### Neutral

- The `DB_Handle` is a limited type, so `Controller_Instance` remains limited (no copy semantics). This is already the case.
- WAL mode requires that the database file and its `-wal` / `-shm` companions be backed up together (ADR-0028 already notes the operator is responsible for backups).

## Alternatives Considered

### Database-only (no in-memory cache)

Every lookup hits SQLite. Simpler (single source of truth) but slower for the supervisor loop, which compares expected vs actual state on every tick.

Why rejected: The supervisor loop runs every second and iterates all agents. Hitting the database on every iteration is unnecessary overhead for local reads that can be served from memory.

### Write-behind caching

Batch writes to the database on a timer or at shutdown. Reduces write frequency but introduces a window of data loss on crash and requires complex flush logic.

Why rejected: The write latency for local SQLite is negligible. The added complexity isn't justified.

### ORM-style abstraction layer

A higher-level abstraction that maps Ada types to tables automatically, similar to an ORM.

Why rejected: Over-engineering for the current scale. Each entity's domain operations are small and specific. An ORM would add complexity without benefit. If the schema grows significantly, this decision can be revisited.

### CRUD procedures on the parent package

Put `Insert_Agent`, `Update_Agent`, `Delete_Agent`, etc. directly on `Podmander.Controller.Database`, adding `Insert_Service`, `Update_Service`, etc. as new entities arrive.

Why rejected: The parent package would grow without bound. Each entity adds 4–5 procedures, and the naming becomes repetitive (`Insert_Agent`, `Insert_Service`, `Insert_Secret`). Domain-driven operations in `Repository` packages keep each package focused and the vocabulary meaningful.

### Centralized entity repositories under Database (Database.Agents, Database.Services)

Put all entity persistence under `Podmander.Controller.Database` as child packages: `Database.Agents`, `Database.Services`, `Database.Secrets`.

Why rejected: As the data layer grows, entity-specific persistence is tightly coupled to its domain logic. Centralizing all repositories under `Database` separates persistence from the domain it serves, making it harder to navigate and reason about. The Repository pattern (persistence alongside domain) keeps related code together: `Agent.Repository` next to `Agent` domain logic, `Service.Repository` next to `Service` domain logic.

### Surrogate integer primary key for agents

Use an auto-increment `id` column as primary key, with `name` as a unique index.

Why rejected: Agent names are already unique and meaningful. A surrogate key adds a join to every query and an extra column to maintain, with no benefit at this scale. If we later need to support agent renaming, we can add a surrogate key then.

## References

- [ADR-0003: SQLite for Controller State Storage](0003-sqlite-for-controller-state.md)
- [ADR-0005: Three-State Model](0005-three-state-model.md)
- [ADR-0021: Local Master Key with libsodium](0021-local-master-key-libsodium.md)
- [ADR-0028: Operator-Managed State DB Backup](0028-operator-managed-state-backup.md)
- [ada_sqlite3 library](https://github.com/gtnoble/ada-sqlite3)