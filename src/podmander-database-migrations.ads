--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Schema migration infrastructure for the controller's SQLite state store.
--  Migrations are numbered SQL constants applied sequentially on startup.
--  The schema_version table tracks the current migration level.

with Ada.Strings.Unbounded;

package Podmander.Database.Migrations is

   type Migration is record
      Version : Positive;
      SQL     : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   -- A numbered migration script. Version is the target schema level
   -- after this migration runs. SQL is the statement to execute.

   type Migration_Array is array (Positive range <>) of Migration;

   Migration_History : constant Migration_Array;
   -- All known migrations, ordered by version. Applied sequentially
   -- by Run_Pending on startup.

   procedure Run_Pending (Handle : in out DB_Handle);
   -- Read the current schema version from the database and apply any
   -- pending migrations in order. Each migration runs inside a single
   -- transaction  -- either all pending migrations apply or none do.
   -- Raises Database_Error with Schema_Error kind on failure.

private

   -- Migration 001: enable WAL mode and create schema_version table.
   -- PRAGMA journal_mode=WAL runs before the transaction (SQLite
   -- restriction: PRAGMA journal_mode cannot run inside a transaction).
   -- The table creation and seed insert run inside the transaction.

   Migration_001_WAL_SQL : constant String := "PRAGMA journal_mode=WAL;";

   Migration_001_Table_SQL : constant String :=
     "CREATE TABLE IF NOT EXISTS schema_version ("
     & "version INTEGER PRIMARY KEY);"
     & "INSERT OR IGNORE INTO schema_version (version) VALUES (0);";

   -- Full migration 001 combines WAL pragma (pre-transaction) and
   -- table creation (in-transaction). Run_Pending splits execution
   -- at the transaction boundary.
   Migration_001_SQL : constant String :=
     Migration_001_WAL_SQL & Migration_001_Table_SQL;

   Migration_002_SQL : constant String :=
     "CREATE TABLE IF NOT EXISTS agents ("
     & "name       TEXT PRIMARY KEY,"
     & "node_id    TEXT NOT NULL,"
     & "state      TEXT NOT NULL"
     & " CHECK (state IN ('registered', 'unresponsive', 'lost')),"
     & "last_seen  TEXT NOT NULL);";

   Migration_003_SQL : constant String :=
     "CREATE TABLE IF NOT EXISTS controller_settings ("
     & "key   TEXT PRIMARY KEY,"
     & "value TEXT NOT NULL);";

   Migration_004_SQL : constant String :=
     "CREATE TABLE IF NOT EXISTS service_versions ("
     & "service_name  TEXT NOT NULL,"
     & "version       INTEGER NOT NULL,"
     & "image         TEXT NOT NULL,"
     & "env           TEXT NOT NULL,"
     & "ports         TEXT NOT NULL,"
     & "volumes       TEXT NOT NULL,"
     & "description   TEXT NOT NULL DEFAULT '',"
     & "wanted_by     TEXT NOT NULL DEFAULT '',"
     & "created_at    TEXT NOT NULL,"
     & "PRIMARY KEY (service_name, version));";

   Migration_005_SQL : constant String :=
     "CREATE TABLE IF NOT EXISTS actual_state ("
     & "service_name  TEXT NOT NULL,"
     & "node_id       TEXT NOT NULL,"
     & "version       INTEGER NOT NULL,"
     & "updated_at    TEXT NOT NULL,"
     & "PRIMARY KEY (service_name, node_id),"
     & "FOREIGN KEY (service_name, version)"
     & "  REFERENCES service_versions(service_name, version));";

   Migration_006_SQL : constant String :=
     "CREATE TABLE IF NOT EXISTS services ("
     & "id   INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "name TEXT NOT NULL UNIQUE);";

   Migration_007_SQL : constant String :=
     "DROP TABLE IF EXISTS actual_state;"
     & "DROP TABLE IF EXISTS service_versions;"
     & "CREATE TABLE IF NOT EXISTS service_versions ("
     & "id           INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "service_id   INTEGER NOT NULL,"
     & "version      INTEGER NOT NULL,"
     & "image        TEXT NOT NULL,"
     & "env          TEXT NOT NULL,"
     & "ports        TEXT NOT NULL,"
     & "volumes      TEXT NOT NULL,"
     & "description  TEXT NOT NULL DEFAULT '',"
     & "wanted_by    TEXT NOT NULL DEFAULT '',"
     & "created_at   TEXT NOT NULL,"
     & "FOREIGN KEY (service_id) REFERENCES services(id),"
     & "UNIQUE (service_id, version));"
     & "CREATE TABLE IF NOT EXISTS actual_state ("
     & "service_name  TEXT NOT NULL,"
     & "node_id       TEXT NOT NULL,"
     & "version       INTEGER NOT NULL,"
     & "updated_at    TEXT NOT NULL,"
     & "PRIMARY KEY (service_name, node_id));";

   Migration_008_SQL : constant String :=
     "DROP TABLE IF EXISTS actual_state;"
     & "CREATE TABLE IF NOT EXISTS service_catalog ("
     & "id              INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "service_id      INTEGER NOT NULL,"
     & "node_id         TEXT,"
     & "current_version INTEGER NOT NULL DEFAULT 0,"
     & "target_version  INTEGER NOT NULL,"
     & "failed          INTEGER NOT NULL DEFAULT 0,"
     & "updated_at      TEXT NOT NULL,"
     & "FOREIGN KEY (service_id) REFERENCES services(id),"
     & "FOREIGN KEY (service_id, target_version)"
     & "    REFERENCES service_versions(service_id, version)"
     & ");"
     & "CREATE UNIQUE INDEX idx_catalog_scheduled"
     & "    ON service_catalog(service_id, node_id)"
     & "    WHERE node_id IS NOT NULL;";

   --  Migration 009: Replace failed boolean with state enum.
   --  SQLite doesn't support ALTER COLUMN, so we rename the column
   --  and convert values: 0 (not failed) -> 0 (Pending), 1 (failed) -> 2 (Failed).
   Migration_009_SQL : constant String :=
     "ALTER TABLE service_catalog RENAME COLUMN failed TO state;"
     & "UPDATE service_catalog SET state = 2 WHERE state = 1;";

   --  Migration 010: Add CHECK constraints to enforce data integrity.
   --  SQLite doesn't support ALTER TABLE ADD CONSTRAINT, so we recreate
   --  the tables with the constraints included.
   --
   --  service_versions: CHECK (version >= 1) - version must be positive.
   --  service_catalog: CHECK (state IN (0, 1, 2, 3)) - state enum values.
   --  service_catalog: CHECK (current_version >= 0) - non-negative.
   Migration_010_SQL : constant String :=
   --  service_versions: recreate with CHECK (version >= 1)
     "CREATE TABLE service_versions_new ("
     & "id           INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "service_id   INTEGER NOT NULL,"
     & "version      INTEGER NOT NULL CHECK (version >= 1),"
     & "image        TEXT NOT NULL,"
     & "env          TEXT NOT NULL,"
     & "ports        TEXT NOT NULL,"
     & "volumes      TEXT NOT NULL,"
     & "description  TEXT NOT NULL DEFAULT '',"
     & "wanted_by    TEXT NOT NULL DEFAULT '',"
     & "created_at   TEXT NOT NULL,"
     & "FOREIGN KEY (service_id) REFERENCES services(id),"
     & "UNIQUE (service_id, version));"
     --  Copy data from old table
     & "INSERT INTO service_versions_new"
     & " SELECT id, service_id, version, image, env, ports, volumes,"
     & " description, wanted_by, created_at"
     & " FROM service_versions;"
     --  Drop old table and rename
     & "DROP TABLE service_versions;"
     & "ALTER TABLE service_versions_new RENAME TO service_versions;"
     --  service_catalog: recreate with CHECK constraints
     & "CREATE TABLE service_catalog_new ("
     & "id              INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "service_id      INTEGER NOT NULL,"
     & "node_id         TEXT,"
     & "current_version INTEGER NOT NULL DEFAULT 0 CHECK (current_version >= 0),"
     & "target_version  INTEGER NOT NULL,"
     & "state           INTEGER NOT NULL DEFAULT 0 CHECK (state IN (0, 1, 2, 3)),"
     & "updated_at      TEXT NOT NULL,"
     & "FOREIGN KEY (service_id) REFERENCES services(id),"
     & "FOREIGN KEY (service_id, target_version)"
     & "    REFERENCES service_versions(service_id, version)"
     & ");"
     --  Copy data from old table
     & "INSERT INTO service_catalog_new"
     & " SELECT id, service_id, node_id, current_version, target_version,"
     & " state, updated_at"
     & " FROM service_catalog;"
     --  Drop old table and rename
     & "DROP TABLE service_catalog;"
     & "ALTER TABLE service_catalog_new RENAME TO service_catalog;"
     --  Recreate the partial unique index
     & "CREATE UNIQUE INDEX idx_catalog_scheduled"
     & "    ON service_catalog(service_id, node_id)"
     & "    WHERE node_id IS NOT NULL;";

   --  Migration 011: Add integer primary key to agents and replace
   --  service_catalog.node_id TEXT with agent_id INTEGER FK.
   --  SQLite doesn't support ALTER TABLE ADD COLUMN with PRIMARY KEY
   --  or changes to column types, so we recreate both tables.
   Migration_011_SQL : constant String :=
   --  Recreate agents table with id INTEGER PRIMARY KEY AUTOINCREMENT
     "CREATE TABLE agents_new ("
     & "id        INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "name      TEXT NOT NULL UNIQUE,"
     & "node_id   TEXT NOT NULL,"
     & "state     TEXT NOT NULL CHECK (state IN ('registered', 'unresponsive', 'lost')),"
     & "last_seen TEXT NOT NULL);"
     & "INSERT INTO agents_new (name, node_id, state, last_seen)"
     & " SELECT name, node_id, state, last_seen FROM agents;"
     & "DROP TABLE agents;"
     & "ALTER TABLE agents_new RENAME TO agents;"
     --  Recreate service_catalog with agent_id instead of node_id.
     --  Convert existing TEXT node_id values to integer agent_id via
     --  LEFT JOIN on agents.name. Orphaned rows get NULL agent_id.
     & "CREATE TABLE service_catalog_new ("
     & "id              INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "service_id      INTEGER NOT NULL,"
     & "agent_id        INTEGER REFERENCES agents(id),"
     & "current_version INTEGER NOT NULL DEFAULT 0 CHECK (current_version >= 0),"
     & "target_version  INTEGER NOT NULL,"
     & "state           INTEGER NOT NULL DEFAULT 0 CHECK (state IN (0, 1, 2, 3)),"
     & "updated_at      TEXT NOT NULL,"
     & "FOREIGN KEY (service_id) REFERENCES services(id),"
     & "FOREIGN KEY (service_id, target_version)"
     & "    REFERENCES service_versions(service_id, version)"
     & ");"
     & "INSERT INTO service_catalog_new"
     & " (id, service_id, agent_id, current_version, target_version,"
     & "  state, updated_at)"
     & " SELECT sc.id, sc.service_id, a.id, sc.current_version,"
     & "  sc.target_version, sc.state, sc.updated_at"
     & " FROM service_catalog sc"
     & " LEFT JOIN agents a ON a.name = sc.node_id;"
     & "DROP TABLE service_catalog;"
     & "ALTER TABLE service_catalog_new RENAME TO service_catalog;"
     & "CREATE UNIQUE INDEX idx_catalog_scheduled"
     & "    ON service_catalog(service_id, agent_id)"
     & "    WHERE agent_id IS NOT NULL;";

   --  Migration 012: Rename agents.node_id to connection_id.
   --  The column held the ZeroMQ ROUTER routing identity, not a domain Node.
   Migration_012_SQL : constant String :=
     "ALTER TABLE agents RENAME COLUMN node_id TO connection_id;";

   --  Migration 013: Introduce the Node entity and associate it 1:1
   --  with the Agent. Create the nodes table (identity only), add
   --  agents.node_id FK referencing nodes(id), and backfill one Node
   --  per existing agent (using the agent's name as the node's
   --  machine_name). SQLite cannot ALTER TABLE ADD COLUMN with a FK
   --  constraint, so we recreate the agents table.
   Migration_013_SQL : constant String :=
   --  Step 1: Create nodes table with identity only (YAGNI)
     "CREATE TABLE nodes ("
     & "id           INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "machine_name TEXT NOT NULL UNIQUE);"
     --  Step 2: Backfill nodes from existing agents (1:1)
     & "INSERT INTO nodes (machine_name)"
     & " SELECT name FROM agents;"
     --  Step 3: Recreate agents table with node_id FK (NOT NULL)
     & "CREATE TABLE agents_new ("
     & "id             INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "name           TEXT NOT NULL UNIQUE,"
     & "connection_id  TEXT NOT NULL,"
     & "state          TEXT NOT NULL CHECK (state IN ('registered', 'unresponsive', 'lost')),"
     & "last_seen      TEXT NOT NULL,"
     & "node_id        INTEGER NOT NULL REFERENCES nodes(id));"
     --  Step 4: Copy data, linking each agent to its node via name join
     & "INSERT INTO agents_new (id, name, connection_id, state, last_seen, node_id)"
     & " SELECT a.id, a.name, a.connection_id, a.state, a.last_seen, n.id"
     & " FROM agents a"
     & " JOIN nodes n ON n.machine_name = a.name;"
     --  Step 5: Swap tables
     & "DROP TABLE agents;"
     & "ALTER TABLE agents_new RENAME TO agents;";

   --  Migration 014: Retarget service_catalog placement from agent_id to
   --  node_id. The catalog now references the stable Node entity; Agent is
   --  reached only at deploy time via the resolution path Node -> Agent ->
   --  Connection_Id. Recreate the table (SQLite cannot ALTER column type or
   --  FK inline) and convert existing rows by joining agents on agent_id to
   --  obtain the corresponding node_id.
   Migration_014_SQL : constant String :=
     "CREATE TABLE service_catalog_new ("
     & "id              INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "service_id      INTEGER NOT NULL,"
     & "node_id         INTEGER REFERENCES nodes(id),"
     & "current_version INTEGER NOT NULL DEFAULT 0 CHECK (current_version >= 0),"
     & "target_version  INTEGER NOT NULL,"
     & "state           INTEGER NOT NULL DEFAULT 0 CHECK (state IN (0, 1, 2, 3)),"
     & "updated_at      TEXT NOT NULL,"
     & "FOREIGN KEY (service_id) REFERENCES services(id),"
     & "FOREIGN KEY (service_id, target_version)"
     & "    REFERENCES service_versions(service_id, version)"
     & ");"
     & "INSERT INTO service_catalog_new"
     & " (id, service_id, node_id, current_version, target_version,"
     & "  state, updated_at)"
     & " SELECT sc.id, sc.service_id, a.node_id, sc.current_version,"
     & "  sc.target_version, sc.state, sc.updated_at"
     & " FROM service_catalog sc"
     & " LEFT JOIN agents a ON a.id = sc.agent_id;"
     & "DROP TABLE service_catalog;"
     & "ALTER TABLE service_catalog_new RENAME TO service_catalog;"
     & "CREATE UNIQUE INDEX idx_catalog_scheduled"
     & "    ON service_catalog(service_id, node_id)"
     & "    WHERE node_id IS NOT NULL;";

   --  Migration 015: Make service_catalog.current_version nullable so that
   --  NULL represents "not yet deployed" rather than the sentinel value 0.
   --  Recreate the table (SQLite cannot ALTER column constraints inline).
   --  Existing rows with current_version = 0 are converted to NULL.
   Migration_015_SQL : constant String :=
     "CREATE TABLE service_catalog_new ("
     & "id              INTEGER PRIMARY KEY AUTOINCREMENT,"
     & "service_id      INTEGER NOT NULL,"
     & "node_id         INTEGER REFERENCES nodes(id),"
     & "current_version INTEGER CHECK (current_version >= 1),"
     & "target_version  INTEGER NOT NULL,"
     & "state           INTEGER NOT NULL DEFAULT 0 CHECK (state IN (0, 1, 2, 3)),"
     & "updated_at      TEXT NOT NULL,"
     & "FOREIGN KEY (service_id) REFERENCES services(id),"
     & "FOREIGN KEY (service_id, target_version)"
     & "    REFERENCES service_versions(service_id, version)"
     & ");"
     & "INSERT INTO service_catalog_new"
     & " (id, service_id, node_id, current_version, target_version,"
     & "  state, updated_at)"
     & " SELECT id, service_id, node_id,"
     & "  CASE WHEN current_version = 0 THEN NULL ELSE current_version END,"
     & "  target_version, state, updated_at"
     & " FROM service_catalog;"
     & "DROP TABLE service_catalog;"
     & "ALTER TABLE service_catalog_new RENAME TO service_catalog;"
     & "CREATE UNIQUE INDEX idx_catalog_scheduled"
     & "    ON service_catalog(service_id, node_id)"
     & "    WHERE node_id IS NOT NULL;";

   Migration_History : constant Migration_Array :=
     [1  =>
        (Version => 1,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_001_SQL)),
      2  =>
        (Version => 2,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_002_SQL)),
      3  =>
        (Version => 3,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_003_SQL)),
      4  =>
        (Version => 4,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_004_SQL)),
      5  =>
        (Version => 5,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_005_SQL)),
      6  =>
        (Version => 6,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_006_SQL)),
      7  =>
        (Version => 7,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_007_SQL)),
      8  =>
        (Version => 8,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_008_SQL)),
      9  =>
        (Version => 9,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_009_SQL)),
      10 =>
        (Version => 10,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_010_SQL)),
      11 =>
        (Version => 11,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_011_SQL)),
      12 =>
        (Version => 12,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_012_SQL)),
      13 =>
        (Version => 13,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_013_SQL)),
      14 =>
        (Version => 14,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_014_SQL)),
      15 =>
        (Version => 15,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_015_SQL))];

end Podmander.Database.Migrations;
