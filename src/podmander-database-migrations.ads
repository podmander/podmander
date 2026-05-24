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

   Migration_History : constant Migration_Array :=
     [1 =>
        (Version => 1,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_001_SQL)),
      2 =>
        (Version => 2,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_002_SQL)),
      3 =>
        (Version => 3,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_003_SQL)),
      4 =>
        (Version => 4,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_004_SQL)),
      5 =>
        (Version => 5,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_005_SQL)),
      6 =>
        (Version => 6,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_006_SQL)),
      7 =>
        (Version => 7,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_007_SQL)),
      8 =>
        (Version => 8,
         SQL     =>
           Ada.Strings.Unbounded.To_Unbounded_String (Migration_008_SQL))];

end Podmander.Database.Migrations;
