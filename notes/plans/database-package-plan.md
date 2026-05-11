# Database Package Implementation Plan

**Issue:** #39 — Implement Database package (open/close, migrations)
**Epic:** #8 — SQLite state storage
**Design reference:** ADR-0035
**Method:** Test-Driven Development (Red-Green cycle per unit)

---

## TDD Method

Each unit follows this cycle:

1. **RED** — Write the test file with test routines for the unit's behaviors. The test won't compile or will fail because the production code doesn't exist yet.
2. **GREEN** — Write the minimum production code to make the tests pass. No extra features.
3. **REFACTOR** — Clean up while keeping tests green. Commit.

The test suite scaffold (`podmander-database_tests.ads/.adb`, `test_runner.adb` registration) is created in Unit 1 alongside the first tests, not in a separate unit at the end.

---

### Unit 1: Error types, DB_Handle, and test scaffold

**Goal:** Define `Database_Error`, `Error_Kind`, `Error_Info`, `Format_Error`, `Parse_Error`, `Classify_Error`, `DB_Handle` type. Establish the test suite scaffold.

**Requirements trace:** R1, R3, R4

**Dependencies:** None

**Files:**
- `tests/podmander-database_tests.ads` — new spec: `Suite` function
- `tests/podmander-database_tests.adb` — new body: test case type, test routines for error types
- `tests/test_runner.adb` — update: register `Podmander.Database_Tests`
- `src/controller/podmander-controller-database.ads` — new spec
- `src/controller/podmander-controller-database.adb` — new body

**TDD Steps:**

**Step 1.1 — RED: Test scaffold + error type tests**

Create `podmander-database_tests.ads/.adb` with:
- `Database_Test` type extending `AUnit.Test_Cases.Test_Case`
- Override `Name` → `"Database Error Types and Handle"`
- Override `Register_Tests`
- Test routines:
  - `Test_Classify_Error_Known_Codes` — codes 19→`Constraint_Violation`, 13→`Device_Full`, 17→`Schema_Error`
  - `Test_Classify_Error_Code_1_Unknown` — `SQLITE_ERROR` (code 1) → `Unknown`
  - `Test_Classify_Error_Unknown_Code` — unrecognized code → `Unknown`
  - `Test_Format_Parse_Error_Roundtrip` — `Format_Error` → `Parse_Error` preserves all fields
  - `Test_Format_Error_Empty_Message` — empty message string round-trips correctly
  - `Test_Parse_Error_Non_Database_Error` — non-`Database_Error` exception → `Kind => Unknown`

Register in `test_runner.adb`:
```ada
with Podmander.Database_Tests;
--  In All_Suites:
AUnit.Test_Suites.Add_Test (Result, Podmander.Database_Tests.Suite);
```

**Expected:** Build fails — `Podmander.Controller.Database` package doesn't exist.

**Step 1.2 — GREEN: Error types and DB_Handle**

Create `podmander-controller-database.ads` with:
- `Database_Error : exception;`
- `type Error_Kind is (Constraint_Violation, Not_Found, Device_Full, Schema_Error, Unknown);`
- `type Error_Info is record Kind : Error_Kind; Message : Unbounded_String; Code : Integer; end record;`
- `function Format_Error (Info : Error_Info) return String;`
- `function Parse_Error (E : Ada.Exceptions.Exception_Occurrence) return Error_Info;`
- `function Classify_Error (Message : String) return Error_Info;`
- `type DB_Handle is limited private;`
- `function Open (Path : String) return DB_Handle;` — stub (raises `Database_Error` with `Unknown`)
- Private part: `type DB_Handle is new Ada.Finalization.Limited_Controlled with record DB : Ada_Sqlite3.Database; end record; overriding procedure Finalize;`

Create `podmander-controller-database.adb` with:
- `Classify_Error` — parse `"<message> (Error code: <n>)"` format, map codes to `Error_Kind`
- `Format_Error` — produce `"[Kind|code] message"` string
- `Parse_Error` — reverse `Format_Error`, extract kind and code from bracketed prefix
- `Open` — stub: raises `Database_Error` with `Unknown` kind
- `Finalize` — empty override (Ada auto-finalizes `Ada_Sqlite3.Database` component)

**Expected:** Build succeeds. Error type tests pass. `Open` tests (Unit 3) will fail on the stub.

**Step 1.3 — REFACTOR**

Clean up any duplication in error formatting/parsing. Commit.

**Verification:** `distrobox enter ada_dev -- alr build && alr test` — error type tests pass, existing tests unaffected.

---

### Unit 2: Migrations child package

**Goal:** Implement the migration engine: `schema_version` table, migration record type, sequential runner with transactional safety.

**Requirements trace:** R7, R8, R9

**Dependencies:** Unit 1 (needs `DB_Handle` and `Database_Error`)

**Files:**
- `tests/podmander-database_tests.adb` — update: add migration test routines
- `src/controller/podmander-controller-database-migrations.ads` — new spec
- `src/controller/podmander-controller-database-migrations.adb` — new body

**TDD Steps:**

**Step 2.1 — RED: Migration tests**

Add test routines to `podmander-database_tests.adb`:
- `Test_Migration_Fresh_DB` — `Run_Pending` on a fresh database creates `schema_version` table with version 1
- `Test_Migration_Idempotent` — `Run_Pending` on a database already at version 1 is a no-op
- `Test_Migration_WAL_Mode` — after `Run_Pending`, `PRAGMA journal_mode` returns "wal"
- `Test_Migration_Rollback_On_Error` — invalid SQL rolls back transaction, raises `Database_Error` with `Schema_Error` kind
- `Test_Migration_Rollback_Failure` — when both migration and rollback fail, original error is preserved
- `Test_Migration_Empty_Schema_Table` — if `schema_version` exists but has no rows, treats as version 0
- `Test_Migration_Sequential_Version` — adding a second migration to `Migration_History` applies it and updates version

Test infrastructure needed:
- Helper function `Create_Temp_DB` that opens a `DB_Handle` at a temporary file path
- Helper procedure `Cleanup_Temp_DB` that deletes the temp file
- These use `Ada.Directories.Compose` + PID for unique paths

**Expected:** Build fails — `Migrations` child package doesn't exist.

**Step 2.2 — GREEN: Migrations package**

Create `podmander-controller-database-migrations.ads` with:
- `type Migration is record Version : Positive; SQL : Unbounded_String; end record;`
- `Migration_History : constant array (Positive range <>) of Migration;` — initially just migration 001
- `procedure Run_Pending (DB : in out DB_Handle);`

Create `podmander-controller-database-migrations.adb` with:
- Migration 001 SQL:
  ```sql
  PRAGMA journal_mode=WAL;
  CREATE TABLE IF NOT EXISTS schema_version (
      version INTEGER PRIMARY KEY
  );
  INSERT OR IGNORE INTO schema_version (version) VALUES (0);
  ```
  Note: `PRAGMA journal_mode=WAL` runs before the transaction (cannot run inside one). Table creation and seed insert go inside the transaction.

- `Run_Pending` implementation:
  - Read current version: `SELECT version FROM schema_version`
  - If no rows returned → treat as version 0
  - If `Migration_History'Last <= Current_Version` → nothing to do
  - Begin transaction: `EXECUTE "BEGIN"`
  - For each migration with `Version > Current_Version`:
    - `EXECUTE Migration.SQL`
    - `EXECUTE "UPDATE schema_version SET version = " & Version'Image`
  - Commit: `EXECUTE "COMMIT"`
  - On `SQLite_Error`: attempt `EXECUTE "ROLLBACK"` (catch and discard rollback error to preserve original), then re-raise as `Database_Error` with `Schema_Error` kind

**Expected:** Build succeeds. Migration tests pass.

**Step 2.3 — REFACTOR**

Extract common temp DB helpers if needed. Clean up migration SQL formatting. Commit.

**Verification:** `distrobox enter ada_dev -- alr build && alr test` — error type + migration tests pass.

---

### Unit 3: Open function — full implementation

**Goal:** Implement `Database.Open` to create parent directories, open the SQLite connection, enable foreign keys, and run pending migrations.

**Requirements trace:** R2

**Dependencies:** Unit 1 (DB_Handle), Unit 2 (Run_Pending)

**Files:**
- `tests/podmander-database_tests.adb` — update: add Open test routines
- `src/controller/podmander-controller-database.adb` — update: replace stub `Open` with full implementation

**TDD Steps:**

**Step 3.1 — RED: Open tests**

Add test routines to `podmander-database_tests.adb`:
- `Test_Open_Creates_Database` — `Open` creates a new database file at a temp path, `schema_version` table exists
- `Test_Open_Creates_Parent_Dirs` — `Open` creates intermediate directories that don't exist
- `Test_Open_Reopen_Existing` — `Open` on an existing database is a no-op (migrations already applied)
- `Test_Open_Foreign_Keys_Enabled` — after `Open`, `PRAGMA foreign_keys` returns "1"
- `Test_Open_Directory_Error` — `Open` with a path whose parent dir cannot be created raises `Database_Error`
- `Test_Handle_Finalization` — `DB_Handle` going out of scope closes the connection (verified by deleting the file after scope exit)

**Expected:** Tests fail — `Open` is still a stub that raises `Database_Error`.

**Step 3.2 — GREEN: Open implementation**

Replace stub `Open` in `podmander-controller-database.adb`:
- Create parent directories: `Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path))`
- Open connection: `Handle.DB := Ada_Sqlite3.Open (Path)`
- Enable foreign keys: `Handle.DB.Execute ("PRAGMA foreign_keys = ON");`
- Run migrations: `Migrations.Run_Pending (Handle)`
- Return `Handle`

Error handling:
- `Ada_Sqlite3.SQLite_Error` → catch and re-raise as `Database_Error` with classified `Error_Info`
- `Ada.Directories.Use_Error` / `Name_Error` → catch and re-raise as `Database_Error` with `Unknown` kind

**Expected:** Build succeeds. Open tests pass.

**Step 3.3 — REFACTOR**

Review error handling for consistency. Ensure `Open` and `Run_Pending` error paths use the same classification pattern. Commit.

**Verification:** `distrobox enter ada_dev -- alr build && alr test` — all database tests pass.

---

### Unit 4: Controller integration — DB_Path and DB_Handle fields

**Goal:** Add `DB_Path` to `Controller_Config`, add `DB` field to `Controller_Instance`, and call `Database.Open` in `Make_Listening_Controller`.

**Requirements trace:** R10, R11, R12

**Dependencies:** Unit 3 (Open function)

**Files:**
- `tests/podmander-controller_tests.adb` — update: add DB integration tests, adjust `Make_Ctrl` helper
- `src/controller/podmander-controller.ads` — update: add `DB_Path`, `DB`, accessors
- `src/controller/podmander-controller.adb` — update: implement accessors, update `Make_Listening_Controller`

**TDD Steps:**

**Step 4.1 — RED: Controller integration tests**

Add test routines to `podmander-controller_tests.adb`:
- `Test_Controller_DB_Path_Accessors` — `Set_DB_Path` / `Get_DB_Path` round-trip correctly
- `Test_Controller_Make_With_DB` — `Make_Listening_Controller` with `:memory:` DB path returns instance with open `DB` handle
- `Test_Controller_Make_DB_Open_Fails` — `Make_Listening_Controller` with invalid `DB_Path` raises `Database_Error` without orphaning socket resources

Update `Make_Ctrl` helper to set `DB_Path` to `:memory:` so existing tests continue to work.

**Expected:** Build fails — `Controller_Config` doesn't have `DB_Path`, `Controller_Instance` doesn't have `DB`.

**Step 4.2 — GREEN: Controller changes**

Update `podmander-controller.ads`:
- Add `DB_Path : Unbounded_String := To_Unbounded_String ("");` to `Controller_Config`
  ```ada
  --  Uses Unbounded_String (not fixed String like Bind_Address) because
  --  filesystem paths vary widely in length; Bind_Address uses fixed
  --  String because it comes from CLI parsing with known max length.
  ```
- Add `Set_DB_Path` / `Get_DB_Path` (following `Set_Bind_Address`/`Get_Bind_Address` pattern)
- Add `DB : Database.DB_Handle;` to `Controller_Instance`

Update `podmander-controller.adb`:
- Implement `Set_DB_Path` / `Get_DB_Path`
- Update `Make_Listening_Controller`:
  - **Open DB before socket bind** — if DB open fails, no socket resources are orphaned
  - Compute effective path: `Get_DB_Path (Config)` if non-empty, else `HOME/.local/share/podmander/state.db`
  - Call `Self.DB := Database.Open (Effective_Path)`
  - Then proceed with certificate generation, socket open, and bind

**Expected:** Build succeeds. Controller integration tests pass. All existing controller tests pass (using `:memory:` via updated `Make_Ctrl`).

**Step 4.3 — REFACTOR**

Review `Make_Listening_Controller` initialization order. Ensure the DB-open-before-socket pattern is clear. Commit.

**Verification:** `distrobox enter ada_dev -- alr build && alr test` — all tests pass (existing + new).

---

## Quality Bar Checklist

- [x] Every unit has a requirements trace
- [x] Dependencies form a DAG (Unit 1 → Unit 2 → Unit 3 → Unit 4)
- [x] Every unit has at least 3 test scenarios written BEFORE production code
- [x] No unit touches >8 files (Unit 1: 5, Unit 2: 3, Unit 3: 2, Unit 4: 4)
- [x] No more than 2 new abstractions introduced per unit (Unit 1: DB_Handle + Error_Info; Unit 2: Migration + Run_Pending; Unit 3: Open implementation; Unit 4: DB_Path field + integration)
- [x] Every planning-time unknown is classified as deferred or resolved
- [x] TDD compliance: every unit follows Red-Green-Refactor, tests are written first
- [x] Handoff completeness test: an engineer follows the Red-Green steps without inventing behavioral requirements

---

## Review Findings (Phase 5 — Engineering Review)

Resolved P1 findings (applied to plan above):

| ID | Finding | Resolution |
|----|---------|------------|
| F1 | `Classify_Error` format was deferred but is now knowable | Documented: `ada_sqlite3.Raise_Error` produces `"<msg> (Error code: <n>)"` |
| F2 | `DB_Handle.Finalize` contradictory between Unit 1 and Unit 3 | Fixed: empty override only. Ada auto-finalizes components. |
| F3 | `Open` called after socket bind — orphaned resources on failure | Fixed: DB open moved before socket bind in `Make_Listening_Controller` |
| F4 | Two string-field patterns in `Controller_Config` | Added decision rule comment in code |
| F5 | `Run_Pending` doesn't handle empty/corrupt `schema_version` | Added: empty table → version 0; rollback error preserved |
| F6-F8 | Missing test coverage for error paths | Tests integrated into each unit's Red step |

Accepted P2 findings (noted for future hardening, not blocking):

| ID | Finding | Action |
|----|---------|--------|
| F10 | No file permissions specified for DB file | Note as future hardening when secrets are stored |
| F11 | Path traversal risk if `DB_Path` from untrusted input | Acceptable for MVP (operator is trusted) |
| F12 | `Format_Error`/`Parse_Error` is a fragile serialization contract | Document format as stable contract |
| F13 | Relative path handling in `Open` unspecified | `Open` expects absolute path; document this |
