--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Database connection lifecycle, error classification, and migration
--  infrastructure for the controller's SQLite state store.
--
--  This package owns the DB_Handle (wrapping Ada_Sqlite3.Database) and
--  exposes it to the Repository packages. Each Repository child package
--  provides domain-driven operations — not generic CRUD — named after the
--  business events that trigger them.

with Ada.Exceptions;
with Ada.Finalization;
with Ada.Strings.Unbounded;
with Ada_Sqlite3;

package Podmander.Database is

   Database_Error : exception;
   --  Raised on any unrecoverable database operation failure.
   --  The exception message carries a structured error description
   --  (see Error_Kind and Format_Error below).

   type Error_Kind is
     (Constraint_Violation,
      Not_Found,
      Device_Full,
      Schema_Error,
      Unknown);
   --  Classification of SQLite error conditions. Used by callers that
   --  need to distinguish failure modes (e.g., UNIQUE violation vs I/O).

   type Error_Info is record
      Kind    : Error_Kind;
      Message : Ada.Strings.Unbounded.Unbounded_String;
      Code    : Integer;
   end record;
   --  Structured error context preserved from the original SQLite_Error.
   --  Code is the raw SQLite result code (e.g., 19 = SQLITE_CONSTRAINT).
   --  Message is the original SQLite error string.

   function Format_Error (Info : Error_Info) return String;
   --  Format Error_Info into a human-readable string for the
   --  Database_Error exception message. Format: "[Kind|code] message"

   function Parse_Error
     (E : Ada.Exceptions.Exception_Occurrence) return Error_Info;
   --  Extract Error_Info from a Database_Error exception occurrence.
   --  Returns Kind => Unknown if the message cannot be parsed.

   function Classify_Error (Message : String) return Error_Info;
   --  Parse an ada_sqlite3 exception message and map the SQLite result
   --  code to an Error_Kind. The ada_sqlite3 library formats messages
   --  as "<description> (Error code: <n>)".

   type DB_Handle is limited private;
   --  Opaque handle wrapping the SQLite connection.
   --  Controlled: finalization closes the connection and releases
   --  all prepared statements automatically. No explicit Close needed.

   function Open (Path : String) return DB_Handle;
   --  Open (or create) the database at Path, create parent directories
   --  if needed, enable WAL mode and foreign keys, and run pending
   --  migrations. Returns a ready-to-use handle.
   --  Raises Database_Error on failure.

   type Query_Handle is limited private;
   --  Wraps a prepared SQLite statement. Auto-finalizes on scope exit.
   --  Repository packages use this instead of Ada_Sqlite3.Statement directly.

   function Prepare
     (DB  : in out DB_Handle;
      SQL : String) return Query_Handle;
   --  Prepare a parameterized query. The returned handle holds a reference
   --  to the connection. Auto-finalized when it goes out of scope.
   --  Raises Database_Error on failure.

   procedure Bind_Text
     (QH    : in out Query_Handle;
      Index : Positive;
      Value : String);
   --  Bind a text value to a parameter by position.

   function Step (QH : in out Query_Handle) return Boolean;
   --  Execute next step. True if a row is available (ROW), False if done.
   --  Raises Database_Error on SQLite errors.

   function Column_Text
     (QH    : Query_Handle;
      Index : Natural) return String;
   --  Read a text column from the current row.

   function Changes (DB : in out DB_Handle) return Integer;
   --  Rows modified by most recent INSERT/UPDATE/DELETE.

   procedure Execute (DB : in out DB_Handle; SQL : String);
   --  Execute a one-shot SQL statement (DDL, PRAGMA, etc.).
   --  Raises Database_Error on failure.

private

   type DB_Handle is new Ada.Finalization.Limited_Controlled with record
      DB : Ada_Sqlite3.Database;
   end record;
   --  Ada automatically finalizes the Ada_Sqlite3.Database component
   --  when DB_Handle goes out of scope. The Finalize override is empty.

   overriding procedure Finalize (Handle : in out DB_Handle);
   --  Empty override. Ada auto-finalizes the DB component after this.
   --  Do NOT call Handle.DB.Finalize explicitly — that would cause
   --  double-finalization.

   type Query_Handle is limited record
      Stmt : Ada_Sqlite3.Statement;
   end record;
   --  Limited but not tagged. The Statement component is controlled
   --  and auto-finalizes when Query_Handle goes out of scope.

end Podmander.Database;
