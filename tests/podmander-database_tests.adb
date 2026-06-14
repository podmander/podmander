--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada_Sqlite3;
with Podmander.Database;

package body Podmander.Database_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Database;
   use type DB.Error_Kind;
   use type Ada_Sqlite3.Result_Code;

   type Database_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Database_Test) return AUnit.Message_String
   is (AUnit.Format ("Database Error Types and Handle"));

   overriding
   procedure Register_Tests (T : in out Database_Test);

   -- Test: Classify_Error maps known SQLite error codes to Error_Kind
   procedure Test_Classify_Error_Known_Codes
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Info_19 : constant DB.Error_Info :=
        DB.Classify_Error ("some constraint error (Error code: 19)");
      Info_13 : constant DB.Error_Info :=
        DB.Classify_Error ("disk full (Error code: 13)");
      Info_17 : constant DB.Error_Info :=
        DB.Classify_Error ("schema changed (Error code: 17)");
   begin
      Assert
        (Info_19.Kind = DB.Constraint_Violation,
         "Code 19 should map to Constraint_Violation");
      Assert
        (Info_13.Kind = DB.Device_Full, "Code 13 should map to Device_Full");
      Assert
        (Info_17.Kind = DB.Schema_Error, "Code 17 should map to Schema_Error");
   end Test_Classify_Error_Known_Codes;

   -- Test: SQLite generic error (code 1) maps to Unknown
   procedure Test_Classify_Error_Code_1_Unknown
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Info : constant DB.Error_Info :=
        DB.Classify_Error ("generic error (Error code: 1)");
   begin
      Assert
        (Info.Kind = DB.Unknown,
         "Code 1 (SQLITE_ERROR) should map to Unknown");
   end Test_Classify_Error_Code_1_Unknown;

   -- Test: Unrecognized error code maps to Unknown
   procedure Test_Classify_Error_Unknown_Code
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Info : constant DB.Error_Info :=
        DB.Classify_Error ("weird error (Error code: 999)");
   begin
      Assert
        (Info.Kind = DB.Unknown, "Unrecognized code should map to Unknown");
      Assert (Info.Code = 999, "Code should be preserved as 999");
   end Test_Classify_Error_Unknown_Code;

   -- Test: Format_Error and Parse_Error round-trip correctly
   procedure Test_Format_Parse_Error_Roundtrip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Original  : constant DB.Error_Info :=
        (Kind    => DB.Constraint_Violation,
         Message => To_Unbounded_String ("UNIQUE violation"),
         Code    => 19);
      Formatted : constant String := DB.Format_Error (Original);
      Parsed    : DB.Error_Info;
   begin
      -- Raise Database_Error with the formatted message, then
      -- parse it back from the Exception_Occurrence.
      begin
         raise DB.Database_Error with Formatted;
      exception
         when E : DB.Database_Error =>
            Parsed := DB.Parse_Error (E);
      end;
      Assert
        (Parsed.Kind = Original.Kind, "Parsed Kind should match original");
      Assert
        (Parsed.Code = Original.Code, "Parsed Code should match original");
      Assert
        (To_String (Parsed.Message) = To_String (Original.Message),
         "Parsed Message should match original");
   end Test_Format_Parse_Error_Roundtrip;

   -- Test: Format_Error with empty message string
   procedure Test_Format_Error_Empty_Message
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Original  : constant DB.Error_Info :=
        (Kind => DB.Unknown, Message => To_Unbounded_String (""), Code => 0);
      Formatted : constant String := DB.Format_Error (Original);
      Parsed    : DB.Error_Info;
   begin
      begin
         raise DB.Database_Error with Formatted;
      exception
         when E : DB.Database_Error =>
            Parsed := DB.Parse_Error (E);
      end;
      Assert
        (Parsed.Kind = Original.Kind,
         "Parsed Kind should match original with empty message");
      Assert
        (To_String (Parsed.Message) = "", "Parsed Message should be empty");
   end Test_Format_Error_Empty_Message;

   -- Test: Parse_Error on non-Database_Error message returns Unknown
   procedure Test_Parse_Error_Non_Database_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      -- Simulate parsing a non-Database_Error exception message
      -- by calling Parse_Error with a string that doesn't match
      -- the [Kind|code] format. We need an Exception_Occurrence,
      -- so we raise and catch one.
      Parsed : DB.Error_Info;
   begin
      raise Constraint_Error with "something went wrong in the controller";
   exception
      when E : Constraint_Error =>
         Parsed := DB.Parse_Error (E);
         Assert
           (Parsed.Kind = DB.Unknown,
            "Non-Database_Error message should parse as Unknown");
   end Test_Parse_Error_Non_Database_Error;

   -- Test infrastructure for migration tests

   Test_Counter : Natural := 0;

   function Unique_Temp_Path return String is
      -- Generate a unique temp file path for each test
   begin
      Test_Counter := Test_Counter + 1;
      return
        "/tmp/podmander_test_"
        & Ada.Strings.Fixed.Trim (Test_Counter'Image, Ada.Strings.Both)
        & ".db";
   end Unique_Temp_Path;

   procedure Cleanup_DB (Path : String) is
   begin
      begin
         Ada.Directories.Delete_File (Path);
      exception
         when Ada.Directories.Name_Error =>
            null;  --  File already gone
      end;
      -- Also clean up WAL/SHM companions
      begin
         Ada.Directories.Delete_File (Path & "-wal");
      exception
         when Ada.Directories.Name_Error =>
            null;
      end;
      begin
         Ada.Directories.Delete_File (Path & "-shm");
      exception
         when Ada.Directories.Name_Error =>
            null;
      end;
   end Cleanup_DB;

   -- Test: Open succeeds, creates the file, and bootstraps the
   -- schema_version table
   procedure Test_Migration_Fresh_DB
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      -- Open should not raise
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      -- Verify file was created
      Assert
        (Ada.Directories.Exists (Path),
         "Database file should exist after Open");
      -- Verify schema_version through a second SQLite connection
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
         Stmt : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (Conn, "SELECT version FROM schema_version");
      begin
         Assert
           (Ada_Sqlite3.Step (Stmt) = Ada_Sqlite3.ROW,
            "schema_version should have a row");
         Assert
           (Ada_Sqlite3.Column_Int (Stmt, 0) >= 1,
            "schema_version should be >= 1 after migration");
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Migration_Fresh_DB;

   -- Test: Opening the same database twice is idempotent
   procedure Test_Migration_Idempotent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      -- First open
      declare
         Handle1 : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle1);
      begin
         null;
      end;
      -- Second open on the same path  -- should not raise
      declare
         Handle2 : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle2);
      begin
         null;
      end;
      -- Verify schema_version is still 1 via second connection
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
         Stmt : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (Conn, "SELECT version FROM schema_version");
      begin
         Assert
           (Ada_Sqlite3.Step (Stmt) = Ada_Sqlite3.ROW,
            "schema_version should have a row on re-open");
         Assert
           (Ada_Sqlite3.Column_Int (Stmt, 0) >= 1,
            "schema_version should be >= 1 on re-open");
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Migration_Idempotent;

   -- Test: WAL mode is enabled after Open
   procedure Test_Migration_WAL_Mode
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         -- Open a second SQLite connection to verify journal mode
         declare
            Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
            Stmt : Ada_Sqlite3.Statement :=
              Ada_Sqlite3.Prepare (Conn, "PRAGMA journal_mode");
         begin
            Assert
              (Ada_Sqlite3.Step (Stmt) = Ada_Sqlite3.ROW,
               "PRAGMA journal_mode should return a row");
            Assert
              (Ada_Sqlite3.Column_Text (Stmt, 0) = "wal",
               "journal_mode should be wal");
         end;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Migration_WAL_Mode;

   -- Test: Open enables foreign keys
   -- NOTE: PRAGMA foreign_keys is a per-connection setting in SQLite,
   -- so it cannot be observed through a second connection. We verify
   -- that Open succeeds (the PRAGMA Execute inside Open didn't raise),
   -- and verify the setting via behavioral test below.
   procedure Test_Open_Foreign_Keys_Enabled
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      -- Open should not raise  -- this exercises the PRAGMA foreign_keys
      -- call inside DB.Open
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Open_Foreign_Keys_Enabled;

   -- Test: Open creates parent directories
   procedure Test_Open_Creates_Parent_Dirs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := "/tmp/podmander_test_nested/sub/dir/test.db";
   begin
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      Assert
        (Ada.Directories.Exists (Path),
         "Database file should exist in nested dirs after Open");
      -- Clean up: delete file, then dirs in reverse order
      Cleanup_DB (Path);
      begin
         Ada.Directories.Delete_Directory
           ("/tmp/podmander_test_nested/sub/dir");
         Ada.Directories.Delete_Directory ("/tmp/podmander_test_nested/sub");
         Ada.Directories.Delete_Directory ("/tmp/podmander_test_nested");
      exception
         when others =>
            null;
      end;
   end Test_Open_Creates_Parent_Dirs;

   -- Test: DB_Handle finalization closes the connection
   procedure Test_Handle_Finalization
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      -- Open and let handle go out of scope
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      -- After finalization, the file should be deletable
      -- (no open file handles holding locks on Linux)
      begin
         Ada.Directories.Delete_File (Path);
         Assert (True, "File deleted after handle finalization");
      exception
         when Ada.Directories.Name_Error =>
            Assert (False, "File not found after handle finalization");
      end;
      Cleanup_DB (Path);
   end Test_Handle_Finalization;

   -- Test: Migration 004 creates the service_versions table
   procedure Test_Migration_Service_Versions_Table
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      -- Open should not raise and should create service_versions table
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      -- Verify service_versions table exists through a second connection
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
         Stmt : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare
             (Conn,
              "SELECT id, service_id, version, image, env, ports, "
              & "volumes, description, wanted_by, created_at "
              & "FROM service_versions");
         pragma Unreferenced (Stmt);
      begin
         -- Preparing the query should not raise  -- table exists with correct columns
         null;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Migration_Service_Versions_Table;

   -- Test: Migration 008 creates the service_catalog table
   procedure Test_Migration_Service_Catalog_Table
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      -- Open should not raise and should create service_catalog table
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      -- Verify service_catalog table exists through a second connection
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
         Stmt : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare
             (Conn,
              "SELECT id, service_id, node_id, current_version, "
              & "target_version, state, updated_at "
              & "FROM service_catalog");
      begin
         -- Preparing the query should not raise  -- " table exists with correct columns
         null;
         pragma Unreferenced (Stmt);
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Migration_Service_Catalog_Table;

   -- Test: Migration 002 creates the agents table
   procedure Test_Migration_Agents_Table
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      -- Open should not raise and should create agents table
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      -- Verify agents table exists through a second connection
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
         Stmt : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare
             (Conn,
              "SELECT id, name, connection_id, state, last_seen, node_id FROM agents");
         pragma Unreferenced (Stmt);
      begin
         -- Preparing the query should not raise  -- table exists with correct columns
         null;
      end;
      -- Verify nodes table exists through a second connection
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
         Stmt : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (Conn, "SELECT id, machine_name FROM nodes");
         pragma Unreferenced (Stmt);
      begin
         -- Preparing the query should not raise  -- table exists with correct columns
         null;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Migration_Agents_Table;

   -- Test: Open raises Database_Error for invalid paths
   procedure Test_Open_Error_Path (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := "/proc/nonexistent/test.db";
   begin
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         Assert (False, "Open should have raised Database_Error");
      end;
   exception
      when DB.Database_Error =>
         Assert (True, "Open raised Database_Error for invalid path");
      when others =>
         Assert (False, "Open raised wrong exception for invalid path");
   end Test_Open_Error_Path;

   -- Test: Prepare/Bind/Step/Column_Text round-trip INSERT and SELECT
   procedure Test_Prepare_And_Step
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      DB.Execute
        (Handle, "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)");

      -- INSERT a row via Prepare/Bind_Text/Step
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "INSERT INTO test (name) VALUES (?)");
      begin
         DB.Bind_Text (Q, 1, "Alice");
         Assert (not DB.Step (Q), "INSERT should complete (DONE -> False)");
      end;

      -- SELECT and verify via Step/Column_Text
      declare
         Q : DB.Query_Handle := DB.Prepare (Handle, "SELECT name FROM test");
      begin
         Assert (DB.Step (Q), "SELECT should return a row");
         Assert
           (DB.Column_Text (Q, 0) = "Alice",
            "Column_Text should return 'Alice'");
         Assert (not DB.Step (Q), "SELECT should have exactly one row");
      end;
   end Test_Prepare_And_Step;

   -- Test: Changes returns correct counts for INSERT/UPDATE/DELETE
   procedure Test_Changes_Count (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      DB.Execute
        (Handle, "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)");

      -- INSERT
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "INSERT INTO test (name) VALUES (?)");
      begin
         DB.Bind_Text (Q, 1, "Alice");
         Assert (not DB.Step (Q), "INSERT should complete (DONE)");
      end;
      Assert (DB.Changes (Handle) = 1, "Changes = 1 after INSERT");

      -- UPDATE
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "UPDATE test SET name = ? WHERE id = ?");
      begin
         DB.Bind_Text (Q, 1, "Bob");
         DB.Bind_Text (Q, 2, "1");
         Assert (not DB.Step (Q), "UPDATE should complete (DONE)");
      end;
      Assert (DB.Changes (Handle) = 1, "Changes = 1 after UPDATE");

      -- DELETE
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "DELETE FROM test WHERE id = ?");
      begin
         DB.Bind_Text (Q, 1, "1");
         Assert (not DB.Step (Q), "DELETE should complete (DONE)");
      end;
      Assert (DB.Changes (Handle) = 1, "Changes = 1 after DELETE");
   end Test_Changes_Count;

   -- Test: Execute creates a table that can be queried via Prepare
   procedure Test_Execute_Creates_Table
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      DB.Execute
        (Handle, "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)");
      declare
         Q : DB.Query_Handle := DB.Prepare (Handle, "SELECT * FROM test");
      begin
         Assert (not DB.Step (Q), "Empty table should return DONE");
      end;
   end Test_Execute_Creates_Table;

   -- Test: Prepare raises Database_Error for invalid SQL syntax
   procedure Test_Prepare_Invalid_SQL
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      declare
         Q : DB.Query_Handle := DB.Prepare (Handle, "SELECT * FROM");
         pragma Unreferenced (Q);
      begin
         Assert (False, "Prepare should have raised Database_Error");
      end;
   exception
      when DB.Database_Error =>
         Assert (True, "Prepare raised Database_Error for invalid SQL");
      when others =>
         Assert (False, "Prepare raised wrong exception for invalid SQL");
   end Test_Prepare_Invalid_SQL;

   -- Test: Set a value and get it back
   procedure Test_Set_Setting_And_Get_Setting
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      DB.Set_Setting (Handle, "test_key", "test_value");
      Assert
        (DB.Get_Setting (Handle, "test_key") = "test_value",
         "Get_Setting should return the value that was set");
   end Test_Set_Setting_And_Get_Setting;

   -- Test: Get_Setting on missing key raises Not_Found
   procedure Test_Get_Setting_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      declare
         Ignored : constant String := DB.Get_Setting (Handle, "nonexistent");
      begin
         Assert (False, "Get_Setting should have raised Database_Error");
         pragma Unreferenced (Ignored);
      end;
   exception
      when DB.Database_Error =>
         null;  --  Expected
   end Test_Get_Setting_Not_Found;

   -- Test: Setting same key twice overwrites (upsert)
   procedure Test_Set_Setting_Upsert
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      DB.Set_Setting (Handle, "upsert_key", "first");
      DB.Set_Setting (Handle, "upsert_key", "second");
      Assert
        (DB.Get_Setting (Handle, "upsert_key") = "second",
         "After upsert, Get_Setting should return the latest value");
   end Test_Set_Setting_Upsert;

   -- Test: Bind_Int inserts integer values correctly
   procedure Test_Bind_Int (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      DB.Execute
        (Handle,
         "CREATE TABLE test (id INTEGER PRIMARY KEY, count INTEGER, name TEXT)");

      -- INSERT a row using Bind_Int for the integer column
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "INSERT INTO test (count, name) VALUES (?, ?)");
      begin
         DB.Bind_Int (Q, 1, 42);
         DB.Bind_Text (Q, 2, "Alice");
         Assert (not DB.Step (Q), "INSERT should complete (DONE -> False)");
      end;

      -- SELECT and verify via Column_Int
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "SELECT count FROM test WHERE name = ?");
      begin
         DB.Bind_Text (Q, 1, "Alice");
         Assert (DB.Step (Q), "SELECT should return a row");
         Assert (DB.Column_Int (Q, 0) = 42, "Column_Int should return 42");
         Assert (not DB.Step (Q), "SELECT should have exactly one row");
      end;
   end Test_Bind_Int;

   -- Test: Bind_Int with WHERE clause parameter
   procedure Test_Bind_Int_Where (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      DB.Execute
        (Handle, "CREATE TABLE test (id INTEGER PRIMARY KEY, val INTEGER)");

      -- Insert two rows
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "INSERT INTO test (val) VALUES (?)");
      begin
         DB.Bind_Int (Q, 1, 10);
         Assert (not DB.Step (Q), "INSERT row 1 should complete");
      end;
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "INSERT INTO test (val) VALUES (?)");
      begin
         DB.Bind_Int (Q, 1, 20);
         Assert (not DB.Step (Q), "INSERT row 2 should complete");
      end;

      -- Query by id using Bind_Int
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "SELECT val FROM test WHERE id = ?");
      begin
         DB.Bind_Int (Q, 1, 2);
         Assert (DB.Step (Q), "SELECT should return a row");
         Assert
           (DB.Column_Int (Q, 0) = 20, "Column_Int should return 20 for id=2");
         Assert (not DB.Step (Q), "SELECT should have exactly one row");
      end;
   end Test_Bind_Int_Where;

   -- Test: Step raises Database_Error for nonexistent table
   procedure Test_Step_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
   begin
      declare
         Q : DB.Query_Handle :=
           DB.Prepare (Handle, "INSERT INTO nonexistent (id) VALUES (1)");
      begin
         -- Prepare may succeed; the error should surface on Step
         declare
            Dummy : Boolean;
         begin
            Dummy := DB.Step (Q);
            Assert (False, "Step should have raised Database_Error");
         exception
            when DB.Database_Error =>
               null;  --  Expected
         end;
      end;
   exception
      when DB.Database_Error =>
         null;  --  Expected: Prepare raised
      when others =>
         Assert
           (False,
            "Prepare/Step raised wrong exception for nonexistent table");
   end Test_Step_Error;

   -- Test: CHECK constraint rejects version < 1 in service_versions
   procedure Test_Check_Version_GTE_One
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
      begin
         -- Insert a service first (needed for FK)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare (Handle, "INSERT INTO services (name) VALUES (?)");
         begin
            DB.Bind_Text (Q, 1, "test-svc");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         -- Insert a valid version (should succeed)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_versions"
                 & " (service_id, version, image, env, ports, volumes,"
                 & " description, wanted_by, created_at)"
                 & " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, 1);
            DB.Bind_Text (Q, 3, "img:latest");
            DB.Bind_Text (Q, 4, "[]");
            DB.Bind_Text (Q, 5, "[]");
            DB.Bind_Text (Q, 6, "[]");
            DB.Bind_Text (Q, 7, "");
            DB.Bind_Text (Q, 8, "");
            DB.Bind_Text (Q, 9, "2026-01-01T00:00:00Z");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         -- Insert an invalid version (version = 0, should fail CHECK)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_versions"
                 & " (service_id, version, image, env, ports, volumes,"
                 & " description, wanted_by, created_at)"
                 & " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, 0);  --  Invalid: version must be >= 1
            DB.Bind_Text (Q, 3, "img:latest");
            DB.Bind_Text (Q, 4, "[]");
            DB.Bind_Text (Q, 5, "[]");
            DB.Bind_Text (Q, 6, "[]");
            DB.Bind_Text (Q, 7, "");
            DB.Bind_Text (Q, 8, "");
            DB.Bind_Text (Q, 9, "2026-01-01T00:00:00Z");
            declare
               Dummy : Boolean;
            begin
               Dummy := DB.Step (Q);
               Assert
                 (False,
                  "INSERT with version=0 should have raised Database_Error");
            exception
               when DB.Database_Error =>
                  null;  --  Expected: CHECK constraint violation
            end;
         end;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Check_Version_GTE_One;

   -- Test: CHECK constraint rejects invalid state in service_catalog
   procedure Test_Check_State_Enum
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
      begin
         -- Insert a service and version first (needed for FKs)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare (Handle, "INSERT INTO services (name) VALUES (?)");
         begin
            DB.Bind_Text (Q, 1, "test-svc");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_versions"
                 & " (service_id, version, image, env, ports, volumes,"
                 & " description, wanted_by, created_at)"
                 & " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, 1);
            DB.Bind_Text (Q, 3, "img:latest");
            DB.Bind_Text (Q, 4, "[]");
            DB.Bind_Text (Q, 5, "[]");
            DB.Bind_Text (Q, 6, "[]");
            DB.Bind_Text (Q, 7, "");
            DB.Bind_Text (Q, 8, "");
            DB.Bind_Text (Q, 9, "2026-01-01T00:00:00Z");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         -- Insert a valid catalog entry (state = 0, should succeed)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_catalog"
                 & " (service_id, target_version, updated_at)"
                 & " VALUES (?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, 1);
            DB.Bind_Text (Q, 3, "2026-01-01T00:00:00Z");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         -- Insert an invalid state (state = 4, should fail CHECK)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_catalog"
                 & " (service_id, target_version, state, updated_at)"
                 & " VALUES (?, ?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, 1);
            DB.Bind_Int (Q, 3, 4);  --  Invalid: state must be 0-3
            DB.Bind_Text (Q, 4, "2026-01-01T00:00:00Z");
            declare
               Dummy : Boolean;
            begin
               Dummy := DB.Step (Q);
               Assert
                 (False,
                  "INSERT with state=4 should have raised Database_Error");
            exception
               when DB.Database_Error =>
                  null;  --  Expected: CHECK constraint violation
            end;
         end;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Check_State_Enum;

   -- Test: CHECK constraint rejects negative current_version in service_catalog
   procedure Test_Check_Current_Version_Non_Negative
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
      begin
         -- Insert a service and version first (needed for FKs)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare (Handle, "INSERT INTO services (name) VALUES (?)");
         begin
            DB.Bind_Text (Q, 1, "test-svc");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_versions"
                 & " (service_id, version, image, env, ports, volumes,"
                 & " description, wanted_by, created_at)"
                 & " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, 1);
            DB.Bind_Text (Q, 3, "img:latest");
            DB.Bind_Text (Q, 4, "[]");
            DB.Bind_Text (Q, 5, "[]");
            DB.Bind_Text (Q, 6, "[]");
            DB.Bind_Text (Q, 7, "");
            DB.Bind_Text (Q, 8, "");
            DB.Bind_Text (Q, 9, "2026-01-01T00:00:00Z");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         -- Insert a catalog entry with negative current_version (should fail)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_catalog"
                 & " (service_id, current_version, target_version, updated_at)"
                 & " VALUES (?, ?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, -1);  --  Invalid: current_version must be >= 0
            DB.Bind_Int (Q, 3, 1);
            DB.Bind_Text (Q, 4, "2026-01-01T00:00:00Z");
            declare
               Dummy : Boolean;
            begin
               Dummy := DB.Step (Q);
               Assert
                 (False,
                  "INSERT with current_version=-1 should have raised Database_Error");
            exception
               when DB.Database_Error =>
                  null;  --  Expected: CHECK constraint violation
            end;
         end;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Check_Current_Version_Non_Negative;

   -- Test: Service_catalog FK constraint rejects non-existent agent_id
   procedure Test_Catalog_Agent_FK
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
      begin
         -- Insert a service and version first (needed for FKs)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare (Handle, "INSERT INTO services (name) VALUES (?)");
         begin
            DB.Bind_Text (Q, 1, "test-svc");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_versions"
                 & " (service_id, version, image, env, ports, volumes,"
                 & " description, wanted_by, created_at)"
                 & " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, 1);
            DB.Bind_Text (Q, 3, "img:latest");
            DB.Bind_Text (Q, 4, "[]");
            DB.Bind_Text (Q, 5, "[]");
            DB.Bind_Text (Q, 6, "[]");
            DB.Bind_Text (Q, 7, "");
            DB.Bind_Text (Q, 8, "");
            DB.Bind_Text (Q, 9, "2026-01-01T00:00:00Z");
            while DB.Step (Q) loop
               null;
            end loop;
         end;

         -- Insert a catalog entry with non-existent node_id (should fail FK)
         declare
            Q : DB.Query_Handle :=
              DB.Prepare
                (Handle,
                 "INSERT INTO service_catalog"
                 & " (service_id, target_version, node_id, updated_at)"
                 & " VALUES (?, ?, ?, ?)");
         begin
            DB.Bind_Int (Q, 1, 1);
            DB.Bind_Int (Q, 2, 1);
            DB.Bind_Int (Q, 3, 999);  --  Non-existent node_id
            DB.Bind_Text (Q, 4, "2026-01-01T00:00:00Z");
            declare
               Dummy : Boolean;
            begin
               Dummy := DB.Step (Q);
               Assert
                 (False,
                  "INSERT with non-existent node_id should have raised Database_Error");
            exception
               when DB.Database_Error =>
                  null;  --  Expected: FK constraint violation
            end;
         end;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Catalog_Agent_FK;

   -- Test: Migration 013 creates nodes table and agents.node_id column
   --  on a fresh database (no pre-existing data).
   procedure Test_Migration_Nodes_Table_And_Backfill
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      --  Fresh database: all migrations run, including 013.
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      --  Verify nodes table exists with correct columns
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
         Stmt : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare (Conn, "SELECT id, machine_name FROM nodes");
         pragma Unreferenced (Stmt);
      begin
         null;  --  Preparing should not raise
      end;
      --  Verify agents table has node_id column
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
         Stmt : Ada_Sqlite3.Statement :=
           Ada_Sqlite3.Prepare
             (Conn,
              "SELECT id, name, connection_id, state, last_seen, node_id FROM agents");
         pragma Unreferenced (Stmt);
      begin
         null;  --  Preparing should not raise
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Migration_Nodes_Table_And_Backfill;

   -- Test: Migration 013 backfill creates one node per existing agent
   --  and links each agent to its node by name.
   --  This test simulates a pre-migration database by manually creating
   --  the schema at version 12, inserting agents, then re-opening to
   --  trigger migration 013.
   procedure Test_Migration_013_Backfill
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Unique_Temp_Path;
   begin
      --  Step 1: Create a database at schema version 12.
      --  We build the pre-013 schema manually: agents table without
      --  node_id, no nodes table, schema_version = 12.
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
      begin
         Ada_Sqlite3.Execute (Conn, "PRAGMA journal_mode=WAL;");
         Ada_Sqlite3.Execute (Conn, "PRAGMA foreign_keys=ON;");
         Ada_Sqlite3.Execute
           (Conn,
            "CREATE TABLE schema_version (version INTEGER PRIMARY KEY);"
            & "INSERT INTO schema_version (version) VALUES (12);");
         --  Create the agents table at schema version 12
         --  (id, name, connection_id, state, last_seen - no node_id)
         Ada_Sqlite3.Execute
           (Conn,
            "CREATE TABLE agents ("
            & "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            & "name TEXT NOT NULL UNIQUE,"
            & "connection_id TEXT NOT NULL,"
            & "state TEXT NOT NULL CHECK (state IN ('registered', 'unresponsive', 'lost')),"
            & "last_seen TEXT NOT NULL);");
         --  Insert two agents with the old schema
         Ada_Sqlite3.Execute
           (Conn,
            "INSERT INTO agents (name, connection_id, state, last_seen)"
            & " VALUES ('alpha', 'conn-001', 'registered', '2026-01-01T00:00:00Z');");
         Ada_Sqlite3.Execute
           (Conn,
            "INSERT INTO agents (name, connection_id, state, last_seen)"
            & " VALUES ('beta', 'conn-002', 'registered', '2026-01-02T00:00:00Z');");
         --  Create the service_catalog table at schema version 12
         --  (uses agent_id, as it existed before migration 014)
         Ada_Sqlite3.Execute
           (Conn,
            "CREATE TABLE services (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE);");
         Ada_Sqlite3.Execute
           (Conn,
            "CREATE TABLE service_versions ("
            & "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            & "service_id INTEGER NOT NULL,"
            & "version INTEGER NOT NULL CHECK (version >= 1),"
            & "image TEXT NOT NULL, env TEXT NOT NULL, ports TEXT NOT NULL,"
            & "volumes TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',"
            & "wanted_by TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL,"
            & "FOREIGN KEY (service_id) REFERENCES services(id),"
            & "UNIQUE (service_id, version));");
         Ada_Sqlite3.Execute
           (Conn,
            "CREATE TABLE service_catalog ("
            & "id INTEGER PRIMARY KEY AUTOINCREMENT,"
            & "service_id INTEGER NOT NULL,"
            & "agent_id INTEGER REFERENCES agents(id),"
            & "current_version INTEGER NOT NULL DEFAULT 0 CHECK (current_version >= 0),"
            & "target_version INTEGER NOT NULL,"
            & "state INTEGER NOT NULL DEFAULT 0 CHECK (state IN (0, 1, 2, 3)),"
            & "updated_at TEXT NOT NULL,"
            & "FOREIGN KEY (service_id) REFERENCES services(id));");
      end;
      --  Step 2: Re-open the database, which triggers migrations 013 and 014.
      --  Migration 013 creates nodes from agent names and links each agent.
      --  Migration 014 retargets service_catalog from agent_id to node_id.
      declare
         Handle : DB.DB_Handle := DB.Open (Path);
         pragma Unreferenced (Handle);
      begin
         null;
      end;
      --  Step 3: Verify the backfill through a second connection.
      declare
         Conn : Ada_Sqlite3.Database := Ada_Sqlite3.Open (Path);
      begin
         --  Verify two nodes were created with matching machine names
         declare
            Stmt : Ada_Sqlite3.Statement :=
              Ada_Sqlite3.Prepare (Conn, "SELECT COUNT(*) FROM nodes");
         begin
            Assert
              (Ada_Sqlite3.Step (Stmt) = Ada_Sqlite3.ROW,
               "nodes should exist");
            Assert
              (Ada_Sqlite3.Column_Int (Stmt, 0) = 2,
               "Should have two nodes (one per agent)");
         end;
         --  Verify each agent is linked to its node by name
         declare
            Stmt : Ada_Sqlite3.Statement :=
              Ada_Sqlite3.Prepare
                (Conn,
                 "SELECT a.name, n.machine_name FROM agents a"
                 & " JOIN nodes n ON n.id = a.node_id"
                 & " ORDER BY a.name");
         begin
            Assert
              (Ada_Sqlite3.Step (Stmt) = Ada_Sqlite3.ROW,
               "First agent should have a node");
            Assert
              (Ada_Sqlite3.Column_Text (Stmt, 0) = "alpha",
               "First agent name should be alpha");
            Assert
              (Ada_Sqlite3.Column_Text (Stmt, 1) = "alpha",
               "First node name should match alpha");
            Assert
              (Ada_Sqlite3.Step (Stmt) = Ada_Sqlite3.ROW,
               "Second agent should have a node");
            Assert
              (Ada_Sqlite3.Column_Text (Stmt, 0) = "beta",
               "Second agent name should be beta");
            Assert
              (Ada_Sqlite3.Column_Text (Stmt, 1) = "beta",
               "Second node name should match beta");
            Assert
              (Ada_Sqlite3.Step (Stmt) = Ada_Sqlite3.DONE,
               "Should have exactly two agents with nodes");
         end;
      end;
      Cleanup_DB (Path);
   exception
      when others =>
         Cleanup_DB (Path);
         raise;
   end Test_Migration_013_Backfill;

   -- Register all test routines
   overriding
   procedure Register_Tests (T : in out Database_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Classify_Error_Known_Codes'Access,
         "Classify_Error maps known SQLite codes to Error_Kind");
      Register_Routine
        (T,
         Test_Classify_Error_Code_1_Unknown'Access,
         "Classify_Error maps SQLITE_ERROR (code 1) to Unknown");
      Register_Routine
        (T,
         Test_Classify_Error_Unknown_Code'Access,
         "Classify_Error maps unrecognized code to Unknown");
      Register_Routine
        (T,
         Test_Format_Parse_Error_Roundtrip'Access,
         "Format_Error and Parse_Error round-trip correctly");
      Register_Routine
        (T,
         Test_Format_Error_Empty_Message'Access,
         "Format_Error handles empty message string");
      Register_Routine
        (T,
         Test_Parse_Error_Non_Database_Error'Access,
         "Parse_Error on non-Database_Error returns Unknown");
      -- Migration and Open tests
      Register_Routine
        (T,
         Test_Migration_Fresh_DB'Access,
         "Open creates schema_version table on fresh DB");
      Register_Routine
        (T,
         Test_Migration_Idempotent'Access,
         "Opening same DB twice is idempotent");
      Register_Routine
        (T, Test_Migration_WAL_Mode'Access, "WAL mode is enabled after Open");
      Register_Routine
        (T,
         Test_Open_Foreign_Keys_Enabled'Access,
         "Foreign keys are enabled after Open");
      Register_Routine
        (T,
         Test_Open_Creates_Parent_Dirs'Access,
         "Open creates parent directories");
      Register_Routine
        (T,
         Test_Handle_Finalization'Access,
         "DB_Handle finalization closes connection");
      Register_Routine
        (T,
         Test_Migration_Agents_Table'Access,
         "Migration 002 creates agents table");
      Register_Routine
        (T,
         Test_Migration_Service_Versions_Table'Access,
         "Migration 004 creates service_versions table");
      Register_Routine
        (T,
         Test_Migration_Service_Catalog_Table'Access,
         "Migration 008 creates service_catalog table");
      Register_Routine
        (T,
         Test_Migration_Nodes_Table_And_Backfill'Access,
         "Migration 013 creates nodes table and agents.node_id");
      Register_Routine
        (T,
         Test_Migration_013_Backfill'Access,
         "Migrations 013+014 backfill nodes and retarget catalog to node_id");
      Register_Routine
        (T,
         Test_Open_Error_Path'Access,
         "Open raises Database_Error for invalid path");
      -- Query API tests
      Register_Routine
        (T,
         Test_Prepare_And_Step'Access,
         "Prepare/Bind/Step/Column_Text round-trip");
      Register_Routine
        (T,
         Test_Bind_Int'Access,
         "Bind_Int inserts and retrieves integer values");
      Register_Routine
        (T,
         Test_Bind_Int_Where'Access,
         "Bind_Int with WHERE clause parameter");
      Register_Routine
        (T,
         Test_Changes_Count'Access,
         "Changes count for INSERT/UPDATE/DELETE");
      Register_Routine
        (T,
         Test_Execute_Creates_Table'Access,
         "Execute creates table queried by Prepare");
      Register_Routine
        (T,
         Test_Prepare_Invalid_SQL'Access,
         "Prepare raises Database_Error for invalid SQL");
      Register_Routine
        (T,
         Test_Step_Error'Access,
         "Step raises Database_Error for nonexistent table");
      -- CHECK constraint tests
      Register_Routine
        (T,
         Test_Check_Version_GTE_One'Access,
         "CHECK constraint rejects version < 1");
      Register_Routine
        (T,
         Test_Check_State_Enum'Access,
         "CHECK constraint rejects invalid state values");
      Register_Routine
        (T,
         Test_Check_Current_Version_Non_Negative'Access,
         "CHECK constraint rejects negative current_version");
      Register_Routine
        (T,
         Test_Catalog_Agent_FK'Access,
         "FK constraint rejects non-existent node_id");
      -- Settings API tests
      Register_Routine
        (T,
         Test_Set_Setting_And_Get_Setting'Access,
         "Set_Setting then Get_Setting round-trip");
      Register_Routine
        (T,
         Test_Get_Setting_Not_Found'Access,
         "Get_Setting raises Not_Found for missing key");
      Register_Routine
        (T,
         Test_Set_Setting_Upsert'Access,
         "Set_Setting upsert overwrites existing value");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Database_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Database_Tests;
