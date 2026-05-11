# Database Package Implementation Plan

**Issue:** #39 — Implement Database package (open/close, migrations)
**Epic:** #8 — SQLite state storage
**Design reference:** ADR-0035

---

### Unit 1: Database package — error types and DB_Handle

**Goal:** Define the `Database_Error` exception, `Error_Kind` enumeration, `Error_Info` record, and `DB_Handle` type with controlled finalization.

**Requirements trace:** R1, R3, R4

**Dependencies:** None

**Files:**
- `src/controller/podmander-controller-database.ads` — new spec: `Database_Error`, `Error_Kind`, `Error_Info`, `Format_Error`, `Parse_Error`, `Classify_Error`, `DB_Handle`, `Open`
- `src/controller/podmander-controller-database.adb` — new body: `Format_Error`, `Parse_Error`, `Classify_Error`, `Finalize` (stub `Open` for now)

**Approach:**

1. Create `Podmander.Controller.Database` spec with:
   - `Database_Error : exception;`
   - `type Error_Kind is (Constraint_Violation, Not_Found, Device_Full, Schema_Error, Unknown);`
   - `type Error_Info is record Kind, Message, Code; end record;`
   - `function Format_Error (Info : Error_Info) return String;`
   - `function Parse_Error (E : Exception_Occurrence) return Error_Info;`
   - `function Classify_Error (Message : String) return Error_Info;`
   - `type DB_Handle is limited private;`
   - `function Open (Path : String) return DB_Handle;` (stub for now, full impl in Unit 3)
   - Private part: `type DB_Handle is new Limited_Controlled with record DB : Ada_Sqlite3.Database; end record; overriding procedure Finalize;`

2. Implement `Classify_Error` to parse SQLite error messages and map result codes to `Error_Kind`:
   - Code 19 → `Constraint_Violation`
   - Code 13 → `Device_Full`
   - Code 17 → `Schema_Error`
   - Default → `Unknown`
   - `Not_Found` is NOT derived from SQLite codes — it's detected by `Changes = 0` at the call site (ADR-0035 §4)

3. Implement `Format_Error` to produce a structured string: `"[Constraint_Violation|19] some message"`

4. Implement `Parse_Error` to reverse `Format_Error` — parse the bracketed kind and code from the exception message.

5. Implement `Finalize` — just calls `Ada_Sqlite3.Database.Finalize` on the embedded `DB` field (parent controlled type handles the actual close).

**Patterns:**
- Follow the project's package naming: `Podmander.Controller.Database` → file `podmander-controller-database.ads`
- Follow the existing `Controller_Instance` pattern: limited controlled type with auto-cleanup
- Error classification follows ADR-0035 §4 exactly

**Test scenarios:**
- [ ] Happy path: `Classify_Error` maps known SQLite error codes to correct `Error_Kind`
- [ ] Unknown code: `Classify_Error` returns `Unknown` for unrecognized codes
- [ ] Round-trip: `Format_Error` → `Parse_Error` preserves `Error_Info` fields
- [ ] `Format_Error` output is human-readable (contains kind name, code, message)
- [ ] `Parse_Error` on non-Database_Error message returns `Kind => Unknown`

**Verification:** `distrobox enter ada_dev -- alr build` compiles without errors. Unit tests pass.

**Planning-time unknowns:**
- How `ada_sqlite3` formats its `SQLite_Error` exception messages (need to check at implementation time to write `Classify_Error` correctly). Deferred to implementation.

---

### Unit 2: Migrations child package

**Goal:** Implement the migration engine: `schema_version` table, migration record type, sequential runner with transactional safety.

**Requirements trace:** R7, R8, R9

**Dependencies:** Unit 1 (needs `DB_Handle` and `Database_Error`)

**Files:**
- `src/controller/podmander-controller-database-migrations.ads` — new spec: `Migration` type, `Migration_History`, `Run_Pending`
- `src/controller/podmander-controller-database-migrations.adb` — new body: `Run_Pending`, migration SQL constants

**Approach:**

1. Create `Podmander.Controller.Database.Migrations` spec with:
   - `type Migration is record Version : Positive; SQL : Unbounded_String; end record;`
   - `Migration_History : constant array (Positive range <>) of Migration;` — initially just migration 001
   - `procedure Run_Pending (DB : in out DB_Handle);` — reads current version, applies pending migrations

2. Migration 001 SQL:
   ```sql
   PRAGMA journal_mode=WAL;
   CREATE TABLE IF NOT EXISTS schema_version (
       version INTEGER PRIMARY KEY
   );
   INSERT OR IGNORE INTO schema_version (version) VALUES (0);
   ```
   Note: `PRAGMA journal_mode=WAL` cannot run inside a transaction, so it goes before the transaction. The `schema_version` table creation and seed insert go inside the transaction.

3. `Run_Pending` implementation:
   - Read current version: `SELECT version FROM schema_version` (single-row table)
   - If `Migration_History'Last <= Current_Version`, nothing to do
   - Begin transaction: `EXECUTE "BEGIN"`
   - For each migration with `Version > Current_Version`:
     - `EXECUTE Migration.SQL`
     - `EXECUTE "UPDATE schema_version SET version = " & Version'Image`
   - Commit: `EXECUTE "COMMIT"`
   - On any `SQLite_Error`: `EXECUTE "ROLLBACK"` (best-effort), then re-raise as `Database_Error` with `Schema_Error` kind

4. `Run_Pending` is called by `Open` (Unit 3), not directly by the controller.

**Patterns:**
- Follow the project's child package naming: `Podmander.Controller.Database.Migrations`
- SQL strings as named constants at package level (ADR-0035 §2)
- Transaction pattern: BEGIN → apply → COMMIT, with ROLLBACK on error

**Test scenarios:**
- [ ] Happy path: `Run_Pending` on a fresh database creates `schema_version` table with version 1
- [ ] Idempotent: `Run_Pending` on a database already at version 1 is a no-op
- [ ] WAL mode: after `Run_Pending`, `PRAGMA journal_mode` returns "wal"
- [ ] Error path: a migration with invalid SQL rolls back the transaction and raises `Database_Error` with `Schema_Error` kind
- [ ] Version tracking: after adding a second migration to `Migration_History`, `Run_Pending` applies it and updates version

**Verification:** `distrobox enter ada_dev -- alr build` compiles. Unit tests pass with a temp file database.

**Planning-time unknowns:**
- Whether `PRAGMA journal_mode=WAL` persists across connections (it does in SQLite — set once, persists in the database file). Confirmed: deferred to implementation for verification.
- Whether `ada_sqlite3.Execute` can run `PRAGMA` statements. Likely yes (it wraps `sqlite3_exec`). Deferred to implementation.

---

### Unit 3: Open function — full implementation

**Goal:** Implement `Database.Open` to create parent directories, open the SQLite connection, and run pending migrations.

**Requirements trace:** R2, R10 (partially — `Open` uses the path)

**Dependencies:** Unit 1 (DB_Handle), Unit 2 (Run_Pending)

**Files:**
- `src/controller/podmander-controller-database.ads` — update: `Open` spec unchanged (already declared in Unit 1)
- `src/controller/podmander-controller-database.adb` — update: implement `Open` body

**Approach:**

1. `Open (Path : String) return DB_Handle`:
   - Create parent directories using `Ada.Directories.Create_Path` (with `Ada.Directories.Containing_Directory (Path)`)
   - `Handle.DB := Ada_Sqlite3.Open (Path)` — opens or creates the database file
   - Enable foreign keys: `Handle.DB.Execute ("PRAGMA foreign_keys = ON");`
   - Call `Migrations.Run_Pending (Handle)` — applies any pending migrations
   - Return `Handle`

2. Error handling in `Open`:
   - `Ada_Sqlite3.SQLite_Error` → catch and re-raise as `Database_Error` with classified `Error_Info`
   - `Ada.Directories.Use_Error` / `Name_Error` → catch and re-raise as `Database_Error` with `Unknown` kind and descriptive message

3. `Finalize` for `DB_Handle`:
   - Just calls `Ada.Finalization.Limited_Controlled.Finalize (Limited_Controlled (Handle))` — the parent's Finalize closes the `Ada_Sqlite3.Database` which auto-finalizes all registered statements.

**Patterns:**
- `Ada_Sqlite3.Open` returns a `Database` object (function, not procedure) — assign directly to `Handle.DB`
- Follow the existing `Make_Listening_Controller` pattern: build-and-return in one function

**Test scenarios:**
- [ ] Happy path: `Open` creates a new database file at a temp path, `schema_version` table exists
- [ ] Parent dirs: `Open` creates intermediate directories that don't exist
- [ ] Re-open: `Open` on an existing database is a no-op (migrations already applied)
- [ ] Error path: `Open` with an invalid path raises `Database_Error`
- [ ] Finalization: `DB_Handle` going out of scope closes the connection (verified by attempting to delete the file after scope exit — should succeed on Linux)

**Verification:** `distrobox enter ada_dev -- alr build` compiles. Unit tests pass.

**Planning-time unknowns:** None.

---

### Unit 4: Controller integration — DB_Path and DB_Handle fields

**Goal:** Add `DB_Path` to `Controller_Config`, add `DB` field to `Controller_Instance`, and call `Database.Open` in `Make_Listening_Controller`.

**Requirements trace:** R10, R11, R12

**Dependencies:** Unit 3 (Open function)

**Files:**
- `src/controller/podmander-controller.ads` — update: add `DB_Path` to `Controller_Config`, add `DB` to `Controller_Instance`, add `Set_DB_Path`/`Get_DB_Path`
- `src/controller/podmander-controller.adb` — update: implement `Set_DB_Path`/`Get_DB_Path`, update `Make_Listening_Controller` to call `Database.Open`
- `src/controller/podmander-controller-message_handlers.adb` — no changes needed (doesn't touch DB directly)
- `tests/podmander-controller_tests.adb` — update: `Make_Ctrl` helper may need adjustment for `DB_Path` default

**Approach:**

1. Add to `Controller_Config`:
   ```ada
   DB_Path      : Ada.Strings.Unbounded.Unbounded_String :=
     To_Unbounded_String ("");
   --  Path to the SQLite state database.
   --  Empty string means use default: ~/.local/share/podmander/state.db
   ```
   Use `Unbounded_String` for the path (like `Enrollment.Secret`), not a fixed-length `String` like `Bind_Address`. The bind address uses fixed `String` because it comes from CLI parsing with known max length; the DB path is a filesystem path that can vary widely.

2. Add `Set_DB_Path` and `Get_DB_Path` procedures (following the `Set_Bind_Address`/`Get_Bind_Address` pattern).

3. Add to `Controller_Instance`:
   ```ada
   DB : Database.DB_Handle;
   ```

4. Update `Make_Listening_Controller`:
   - After socket setup, call `Self.DB := Database.Open (Effective_Path)` where `Effective_Path` is `Get_DB_Path (Config)` if non-empty, else the default path.
   - Default path construction: `Ada.Environment_Variables.Value ("HOME") & "/.local/share/podmander/state.db"` — but only when `DB_Path` is empty. This keeps the default out of the config record and makes it computed at runtime.

5. Update `Make_Ctrl` test helper: the `DB_Path` default is empty, and `Make_Listening_Controller` will try to open a real DB. For tests that don't need a DB, we need a strategy:
   - Option A: Use `:memory:` as the DB path in tests (SQLite in-memory database)
   - Option B: Create a temp file for each test
   - **Chosen: Option A** — `:memory:` is the simplest, no file cleanup needed, and `ada_sqlite3` supports it via the `OPEN_MEMORY` flag or the `:memory:` filename convention.

**Patterns:**
- Follow `Set_Bind_Address`/`Get_Bind_Address` pattern for `DB_Path`
- Follow `Controller_Instance` field pattern (limited controlled, default-initialized)
- Use `:memory:` for test databases (standard SQLite testing pattern)

**Test scenarios:**
- [ ] Happy path: `Make_Listening_Controller` with a valid `DB_Path` returns an instance with an open `DB` handle
- [ ] Default path: `Make_Listening_Controller` with empty `DB_Path` uses the default path
- [ ] Existing tests: all existing controller tests still pass (using `:memory:` or no DB interaction)
- [ ] `Set_DB_Path` / `Get_DB_Path` round-trip correctly

**Verification:** `distrobox enter ada_dev -- alr build` compiles. All existing + new tests pass.

**Planning-time unknowns:**
- Whether `ada_sqlite3.Open (":memory:")` works (SQLite supports it natively; the Ada binding should pass it through). Deferred to implementation.
- Whether existing tests that construct `Controller_Instance` directly (like `Make_Ctrl`) will break when `DB` field is added. The `DB` field is default-initialized (controlled type), so it should be fine — but the `DB` handle will be in a "not open" state. Tests that call `Make_Listening_Controller` will get a real DB. Deferred to implementation.

---

### Unit 5: Database package tests

**Goal:** Create the test suite for the `Database` package and `Migrations` child package, and register it in the test runner.

**Requirements trace:** All (R1–R12 test coverage)

**Dependencies:** Units 1–4 (tests the implemented code)

**Files:**
- `tests/podmander-database_tests.ads` — new spec: `Suite` function
- `tests/podmander-database_tests.adb` — new body: all test routines
- `tests/test_runner.adb` — update: add `Podmander.Database_Tests` to `All_Suites`

**Approach:**

1. Create `Podmander.Database_Tests` test case following the existing AUnit pattern:
   - Type extending `AUnit.Test_Cases.Test_Case`
   - Override `Name` and `Register_Tests`
   - Individual test routines as `procedure (T : in out Test_Case'Class)`

2. Test infrastructure:
   - Helper function `Create_Temp_DB` that returns a `DB_Handle` opened at a temporary file path (using `Ada.Directories.Create_Path` + temp dir convention)
   - Helper procedure `Cleanup_Temp_DB` that closes the handle and deletes the file
   - For controller integration tests: use `:memory:` databases

3. Test routines (covering all scenarios from Units 1–4):
   - `Test_Classify_Error_Known_Codes` — Unit 1
   - `Test_Classify_Error_Unknown_Code` — Unit 1
   - `Test_Format_Parse_Error_Roundtrip` — Unit 1
   - `Test_Parse_Error_Non_Database_Error` — Unit 1
   - `Test_Open_Creates_Database` — Unit 3
   - `Test_Open_Creates_Parent_Dirs` — Unit 3
   - `Test_Open_Reopen_Existing` — Unit 3
   - `Test_Migration_Fresh_DB` — Unit 2
   - `Test_Migration_Idempotent` — Unit 2
   - `Test_Migration_WAL_Mode` — Unit 2
   - `Test_Migration_Rollback_On_Error` — Unit 2
   - `Test_Migration_Sequential_Version` — Unit 2
   - `Test_Handle_Finalization` — Unit 3
   - `Test_Controller_DB_Path_Accessors` — Unit 4
   - `Test_Controller_Make_With_DB` — Unit 4

4. Register in `test_runner.adb`:
   ```ada
   with Podmander.Database_Tests;
   --  In All_Suites:
   AUnit.Test_Suites.Add_Test (Result, Podmander.Database_Tests.Suite);
   ```

**Patterns:**
- Follow existing test structure: `Podmander.*_Tests` package, `Suite` function, `Register_Tests` with named routines
- Use `AUnit.Assertions.Assert` for all checks
- Temp file cleanup in test teardown

**Test scenarios:** (listed above — this IS the test unit)

**Verification:** `distrobox enter ada_dev -- alr test` passes all tests (existing + new).

**Planning-time unknowns:**
- How to generate a unique temp file path in Ada without external dependencies. `Ada.Directories.Compose` + PID or timestamp. Deferred to implementation.
- Whether `:memory:` databases work with `ada_sqlite3.Open`. Deferred to implementation.

---

## Quality Bar Checklist

- [x] Every unit has a requirements trace
- [x] Dependencies form a DAG (Unit 1 → Unit 2 → Unit 3 → Unit 4, Unit 5 depends on 1–4)
- [x] Every unit has at least 3 test scenarios
- [x] No unit touches >8 files (Unit 4 touches 4 files, Unit 5 touches 3)
- [x] No more than 2 new abstractions introduced per unit (Unit 1: DB_Handle + Error_Info; Unit 2: Migration + Run_Pending; Unit 3: Open implementation; Unit 4: DB_Path field + integration)
- [x] Every planning-time unknown is classified as deferred
- [x] Handoff completeness test: an engineer would need to check `ada_sqlite3` exception message format and `:memory:` support, but no behavioral invention is needed
