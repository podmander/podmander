--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada_Sqlite3;
with Podmander.Logging;

package body Podmander.Database.Migrations is

   use Ada.Strings.Unbounded;
   use type Ada_Sqlite3.Result_Code;

   procedure Run_Pending (Handle : in out DB_Handle) is
      --  Read the current schema version. If the table doesn't exist
      --  yet (fresh database), the SELECT will fail and we treat it
      --  as version 0 (all migrations pending).
      Current_Version : Natural := 0;
      Have_Version    : Boolean := False;
   begin
      --  Try to read current version
      begin
         declare
            Stmt : Ada_Sqlite3.Statement := Ada_Sqlite3.Prepare (Handle.DB, "SELECT version FROM schema_version");
         begin
            if Ada_Sqlite3.Step (Stmt) = Ada_Sqlite3.ROW then
               Current_Version := Natural (Ada_Sqlite3.Column_Int (Stmt, 0));
               Have_Version := True;
            end if;
         --  Statement auto-finalizes on scope exit
         end;
      exception
         when Ada_Sqlite3.SQLite_Error =>
            --  Table doesn't exist yet ÃÂ¢ÃÂÃÂ fresh database, version 0
            null;
      end;

      --  Nothing to do if already at the latest version
      if Have_Version and then Current_Version >= Migration_History'Last then
         return;
      end if;

      --  Run WAL pragma before the transaction (SQLite restriction)
      if not Have_Version then
         begin
            Handle.DB.Execute (Migration_001_WAL_SQL);
         exception
            when Ada_Sqlite3.SQLite_Error =>
               null;  --  WAL may already be set on existing databases
         end;
      end if;

      --  Apply pending migrations inside a transaction
      Handle.DB.Execute ("BEGIN");
      begin
         --  If fresh database, create the schema_version table first
         if not Have_Version then
            Handle.DB.Execute (Migration_001_Table_SQL);
            Current_Version := 0;
         end if;

         --  Apply each pending migration
         for M of Migration_History loop
            if M.Version > Current_Version then
               --  Skip the WAL pragma portion (already executed above
               --  for fresh databases). Only run the table SQL portion.
               --  For migration 001, the WAL pragma is already done.
               --  For future migrations, the full SQL runs here.
               if M.Version = 1 then
                  --  Migration 001 table creation already done above
                  --  for fresh databases. For existing databases where
                  --  the table exists but version is old, just update.
                  null;
               else
                  Handle.DB.Execute (To_String (M.SQL));
               end if;
               Handle.DB.Execute ("UPDATE schema_version SET version = " & M.Version'Image);
               Podmander.Logging.Info ("database", "Applied migration " & M.Version'Image);
            end if;
         end loop;

         Handle.DB.Execute ("COMMIT");
      exception
         when E : Ada_Sqlite3.SQLite_Error =>
            --  Attempt rollback, discarding any rollback error to
            --  preserve the original failure information.
            begin
               Handle.DB.Execute ("ROLLBACK");
            exception
               when Ada_Sqlite3.SQLite_Error =>
                  null;  --  Best-effort rollback
            end;
            raise Database_Error with Format_Error (Classify_Error (Ada.Exceptions.Exception_Message (E)));
      end;
   end Run_Pending;

end Podmander.Database.Migrations;
