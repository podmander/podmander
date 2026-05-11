# Database Package Requirements

**Version:** 1.0
**Status:** Draft
**Date:** 2026-05-11

## Problem Frame

The controller currently stores all state in memory (`Agent_Maps.Map`). On restart, everything is lost — no agents can reconnect, no scheduling decisions persist. ADR-0003 selected SQLite as the persistent store, and ADR-0035 designed the database layer. This issue implements the foundation: the `Podmander.Controller.Database` package with connection lifecycle (open/close) and the migration engine. Without this, no other persistence work (agents table, repository operations, state sync) can proceed.

## Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R1 | `DB_Handle` type wrapping `Ada_Sqlite3.Database` with controlled finalization (auto-close on scope exit) | Must Have | ADR-0035 §4; extends `Limited_Controlled` |
| R2 | `Open` function that creates/opens a SQLite database file, enables WAL mode, and runs pending migrations | Must Have | ADR-0035 §2, §4; returns `DB_Handle` |
| R3 | `Database_Error` exception with structured `Error_Info` (Kind, Code, Message) for classifying failures | Must Have | ADR-0035 §4; wraps `Ada_Sqlite3.SQLite_Error` |
| R4 | `Error_Kind` enumeration: `Constraint_Violation`, `Not_Found`, `Device_Full`, `Schema_Error`, `Unknown` | Must Have | ADR-0035 §4; derived from SQLite result codes |
| R5 | `Format_Error` and `Parse_Error` subprograms for `Error_Info` ↔ exception message conversion | Must Have | ADR-0035 §4; enables caller-side error classification |
| R6 | `Classify_Error` function mapping SQLite result codes to `Error_Kind` values | Must Have | ADR-0035 §4; internal helper used by Repository packages |
| R7 | `Migrations` child package with `schema_version` table creation and sequential migration runner | Must Have | ADR-0035 §2; runs migrations in a transaction |
| R8 | Migration runner reads current version from `schema_version`, applies pending migrations in order, rolls back on failure | Must Have | ADR-0035 §2; idempotent within version |
| R9 | `PRAGMA journal_mode=WAL` set during initial migration | Must Have | ADR-0035 §7; crash recovery guarantee |
| R10 | `Controller_Config` gains a `DB_Path` field (default: `~/.local/share/podmander/state.db`) | Must Have | ADR-0035 §6; needed for `Open` call |
| R11 | `Controller_Instance` gains a `DB` field of type `Database.DB_Handle` | Must Have | ADR-0035 §5; write-through cache needs a handle |
| R12 | `Make_Listening_Controller` calls `Database.Open` during initialization | Must Have | ADR-0035 §6; startup behavior |

## Success Criteria

- `Database.Open` creates a new SQLite file with `schema_version` table and WAL mode enabled
- `Database.Open` on an existing database reads the current version and applies no migrations if up-to-date
- `Database.Open` on an existing database with pending migrations applies them in order within a transaction
- Failed migration rolls back the transaction and raises `Database_Error` with `Schema_Error` kind
- `DB_Handle` finalization closes the connection automatically
- `Database_Error` carries structured `Error_Info` that callers can parse
- `Controller_Instance` has a `DB` field and `Make_Listening_Controller` initializes it
- All existing tests continue to pass

## Scope Boundaries

**In scope:**
- `Podmander.Controller.Database` package (spec + body)
- `Podmander.Controller.Database.Migrations` child package (spec + body)
- `Database_Error` exception, `Error_Kind`, `Error_Info`, `Format_Error`, `Parse_Error`, `Classify_Error`
- `DB_Handle` type with controlled finalization
- `Open` function (connection + WAL + migrations)
- `schema_version` table as the initial/only migration
- `Controller_Config.DB_Path` field
- `Controller_Instance.DB` field
- `Make_Listening_Controller` DB initialization
- Unit tests for all of the above

**Out of scope:**
- Agents table migration (issue #40)
- Agent.Repository domain operations (issue #42)
- State sync / write-through cache wiring (issues #43, #44)
- Controller registration token persistence (issue #50)
- ISO 8601 timestamp conversion utility (needed by #42, not #39)
- Prepared statement caching (needed by #42, not #39)

## Key Decisions

| Decision | Chosen | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Migration scope for #39 | `schema_version` table only | Clean separation: infrastructure in #39, first real migration in #40 | Include agents table too (blurs scope boundary) |
| `DB_Handle` wrapping | Extend `Limited_Controlled` with `Ada_Sqlite3.Database` field | Matches ADR-0035; `Ada_Sqlite3.Database` is already controlled, so `Finalize` just calls parent | Direct use of `Ada_Sqlite3.Database` without wrapper (loses error classification layer) |
| Migration storage | Named constant SQL strings in `Migrations` package | Simple, no external files, compile-time checked | External SQL files (adds runtime dependency, harder to test) |
| Migration transaction | Wrap all pending migrations in a single transaction | Atomic: either all apply or none do | Per-migration transactions (partial application on failure) |
| `Open` function vs procedure | Function returning `DB_Handle` | Matches `Ada_Sqlite3.Open` pattern; controlled initialization | Procedure with `in out DB_Handle` (requires default-initialized handle) |

## Outstanding Questions

| # | Question | Impact if Wrong | Owner |
|---|----------|-----------------|-------|
| Q1 | ~~Should `Open` create parent directories for the DB path if they don't exist?~~ **Resolved: Yes.** `Open` creates parent directories on first run. | — | Jochen |
