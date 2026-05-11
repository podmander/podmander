--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Strings.Fixed;
with Podmander.Database.Migrations;
with Podmander.Logging;

package body Podmander.Database is

   use Ada.Strings.Unbounded;

   --  Format: "[Kind|code] message"
   function Format_Error (Info : Error_Info) return String is
      Result : Unbounded_String;
   begin
      Append (Result, "[");
      Append (Result, Info.Kind'Image);
      Append (Result, "|");
      Append (Result, Ada.Strings.Fixed.Trim (Info.Code'Image, Ada.Strings.Both));
      Append (Result, "] ");
      Append (Result, Info.Message);
      return To_String (Result);
   end Format_Error;

   --  Reverse of Format_Error: parse "[Kind|code] message"
   function Parse_Error
     (E : Ada.Exceptions.Exception_Occurrence) return Error_Info
   is
      Msg : constant String := Ada.Exceptions.Exception_Message (E);
      --  Try to parse "[Kind|code] message" format
      Bracket_Start : constant Natural := Ada.Strings.Fixed.Index (Msg, "[");
      Pipe_Pos      : constant Natural := Ada.Strings.Fixed.Index (Msg, "|");
      Bracket_End   : constant Natural := Ada.Strings.Fixed.Index (Msg, "]");
   begin
      if Bracket_Start = 0 or else Pipe_Pos = 0
        or else Bracket_End = 0
        or else Pipe_Pos <= Bracket_Start + 1
        or else Bracket_End <= Pipe_Pos + 1
      then
         return (Kind => Unknown, Message => To_Unbounded_String (Msg), Code => 0);
      end if;

      declare
         Kind_Str : constant String :=
           Msg (Bracket_Start + 1 .. Pipe_Pos - 1);
         Code_Str : constant String :=
           Msg (Pipe_Pos + 1 .. Bracket_End - 1);
         Rest     : constant String :=
           Msg (Bracket_End + 2 .. Msg'Last);  --  skip "] "
      begin
         return
           (Kind    => Error_Kind'Value (Kind_Str),
            Message => To_Unbounded_String (Rest),
            Code    => Integer'Value (Code_Str));
      exception
         when Constraint_Error =>
            return (Kind => Unknown,
                    Message => To_Unbounded_String (Msg),
                    Code    => 0);
      end;
   end Parse_Error;

   --  Parse ada_sqlite3 format: "<description> (Error code: <n>)"
   function Classify_Error (Message : String) return Error_Info is
      Prefix : constant String := "(Error code: ";
      Code_Start : constant Natural :=
        Ada.Strings.Fixed.Index (Message, Prefix);
   begin
      if Code_Start = 0 then
         return (Kind    => Unknown,
                 Message => To_Unbounded_String (Message),
                 Code    => 0);
      end if;

      declare
         Num_Start : constant Positive := Code_Start + Prefix'Length;
         Num_End   : Natural := Num_Start;
      begin
         --  Find the closing paren
         while Num_End <= Message'Last
           and then Message (Num_End) /= ')'
         loop
            Num_End := Num_End + 1;
         end loop;

         if Num_End > Message'Last then
            return (Kind    => Unknown,
                    Message => To_Unbounded_String (Message),
                    Code    => 0);
         end if;

         declare
            Code_Str : constant String :=
              Message (Num_Start .. Num_End - 1);
            Code     : constant Integer := Integer'Value (Code_Str);
            Desc     : constant String :=
              Message (Message'First .. Code_Start - 2);  --  skip trailing space
         begin
            case Code is
               when 19 =>
                  return (Kind    => Constraint_Violation,
                          Message => To_Unbounded_String (Desc),
                          Code    => Code);
               when 13 =>
                  return (Kind    => Device_Full,
                          Message => To_Unbounded_String (Desc),
                          Code    => Code);
               when 17 =>
                  return (Kind    => Schema_Error,
                          Message => To_Unbounded_String (Desc),
                          Code    => Code);
               when others =>
                  return (Kind    => Unknown,
                          Message => To_Unbounded_String (Desc),
                          Code    => Code);
            end case;
         exception
            when Constraint_Error =>
               return (Kind    => Unknown,
                       Message => To_Unbounded_String (Message),
                       Code    => 0);
         end;
      end;
   end Classify_Error;

   --  Open (or create) the database at Path, create parent directories
   --  if needed, enable WAL mode and foreign keys, and run pending
   --  migrations. Returns a ready-to-use handle.
   function Open (Path : String) return DB_Handle is
   begin
      --  Create parent directories if they don't exist
      declare
         Parent : constant String :=
           Ada.Directories.Containing_Directory (Path);
      begin
         if Parent'Length > 0 then
            Ada.Directories.Create_Path (Parent);
         end if;
      exception
         when Ada.Directories.Use_Error |
              Ada.Directories.Name_Error =>
            raise Database_Error with Format_Error
              ((Kind    => Unknown,
                Message => To_Unbounded_String
                  ("Cannot create directory for: " & Path),
                Code    => 0));
      end;

      --  Open the SQLite connection, configure, and return handle
      return Handle : DB_Handle :=
        (Ada.Finalization.Limited_Controlled with
           DB => Ada_Sqlite3.Open (Path))
      do
         --  Enable foreign keys
         Handle.DB.Execute ("PRAGMA foreign_keys = ON");

         --  Run pending migrations
         Migrations.Run_Pending (Handle);

         Podmander.Logging.Info
           ("database", "Opened database at " & Path);
      end return;
   exception
      when E : Ada_Sqlite3.SQLite_Error =>
         raise Database_Error with Format_Error
           (Classify_Error (Ada.Exceptions.Exception_Message (E)));
   end Open;

   --  Empty override: Ada auto-finalizes the Ada_Sqlite3.Database component
   overriding procedure Finalize (Handle : in out DB_Handle) is
      pragma Unreferenced (Handle);
   begin
      null;
   end Finalize;

end Podmander.Database;
