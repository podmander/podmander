--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Schema migration infrastructure for the controller's SQLite state store.
--  Migrations are numbered SQL constants applied sequentially on startup.
--  The schema_version table tracks the current migration level.

with Ada.Strings.Unbounded;

private with Podmander.Controller.Database;

package Podmander.Controller.Database.Migrations is

   type Migration is record
      Version : Positive;
      SQL     : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   --  A numbered migration script. Version is the target schema level
   --  after this migration runs. SQL is the statement to execute.

   type Migration_Array is array (Positive range <>) of Migration;

   Migration_History : constant Migration_Array;
   --  All known migrations, ordered by version. Applied sequentially
   --  by Run_Pending on startup.

   procedure Run_Pending (Handle : in out DB_Handle);
   --  Read the current schema version from the database and apply any
   --  pending migrations in order. Each migration runs inside a single
   --  transaction — either all pending migrations apply or none do.
   --  Raises Database_Error with Schema_Error kind on failure.

private

   --  Migration 001: enable WAL mode and create schema_version table.
   --  PRAGMA journal_mode=WAL runs before the transaction (SQLite
   --  restriction: PRAGMA journal_mode cannot run inside a transaction).
   --  The table creation and seed insert run inside the transaction.

   Migration_001_WAL_SQL : constant String :=
     "PRAGMA journal_mode=WAL;";

   Migration_001_Table_SQL : constant String :=
     "CREATE TABLE IF NOT EXISTS schema_version (" &
     "version INTEGER PRIMARY KEY);" &
     "INSERT OR IGNORE INTO schema_version (version) VALUES (0);";

   --  Full migration 001 combines WAL pragma (pre-transaction) and
   --  table creation (in-transaction). Run_Pending splits execution
   --  at the transaction boundary.
   Migration_001_SQL : constant String :=
     Migration_001_WAL_SQL & Migration_001_Table_SQL;

   Migration_History : constant Migration_Array :=
     (1 => (Version => 1,
            SQL     => Ada.Strings.Unbounded.To_Unbounded_String
                        (Migration_001_SQL)));

end Podmander.Controller.Database.Migrations;
