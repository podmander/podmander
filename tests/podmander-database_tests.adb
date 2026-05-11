--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Podmander.Controller.Database;

package body Podmander.Database_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Controller.Database;
   use type DB.Error_Kind;

   type Database_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name
     (T : Database_Test) return AUnit.Message_String
   is (AUnit.Format ("Database Error Types and Handle"));

   overriding procedure Register_Tests (T : in out Database_Test);

   --  Test: Classify_Error maps known SQLite error codes to Error_Kind
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
      Assert (Info_19.Kind = DB.Constraint_Violation,
              "Code 19 should map to Constraint_Violation");
      Assert (Info_13.Kind = DB.Device_Full,
              "Code 13 should map to Device_Full");
      Assert (Info_17.Kind = DB.Schema_Error,
              "Code 17 should map to Schema_Error");
   end Test_Classify_Error_Known_Codes;

   --  Test: SQLite generic error (code 1) maps to Unknown
   procedure Test_Classify_Error_Code_1_Unknown
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Info : constant DB.Error_Info :=
        DB.Classify_Error ("generic error (Error code: 1)");
   begin
      Assert (Info.Kind = DB.Unknown,
              "Code 1 (SQLITE_ERROR) should map to Unknown");
   end Test_Classify_Error_Code_1_Unknown;

   --  Test: Unrecognized error code maps to Unknown
   procedure Test_Classify_Error_Unknown_Code
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Info : constant DB.Error_Info :=
        DB.Classify_Error ("weird error (Error code: 999)");
   begin
      Assert (Info.Kind = DB.Unknown,
              "Unrecognized code should map to Unknown");
      Assert (Info.Code = 999,
              "Code should be preserved as 999");
   end Test_Classify_Error_Unknown_Code;

   --  Test: Format_Error and Parse_Error round-trip correctly
   procedure Test_Format_Parse_Error_Roundtrip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Original : constant DB.Error_Info :=
        (Kind    => DB.Constraint_Violation,
         Message => To_Unbounded_String ("UNIQUE violation"),
         Code    => 19);
      Formatted : constant String := DB.Format_Error (Original);
      Parsed    : DB.Error_Info;
   begin
      --  Raise Database_Error with the formatted message, then
      --  parse it back from the Exception_Occurrence.
      begin
         raise DB.Database_Error with Formatted;
      exception
         when E : DB.Database_Error =>
            Parsed := DB.Parse_Error (E);
      end;
      Assert (Parsed.Kind = Original.Kind,
              "Parsed Kind should match original");
      Assert (Parsed.Code = Original.Code,
              "Parsed Code should match original");
      Assert (To_String (Parsed.Message) = To_String (Original.Message),
              "Parsed Message should match original");
   end Test_Format_Parse_Error_Roundtrip;

   --  Test: Format_Error with empty message string
   procedure Test_Format_Error_Empty_Message
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Original : constant DB.Error_Info :=
        (Kind    => DB.Unknown,
         Message => To_Unbounded_String (""),
         Code    => 0);
      Formatted : constant String := DB.Format_Error (Original);
      Parsed    : DB.Error_Info;
   begin
      begin
         raise DB.Database_Error with Formatted;
      exception
         when E : DB.Database_Error =>
            Parsed := DB.Parse_Error (E);
      end;
      Assert (Parsed.Kind = Original.Kind,
              "Parsed Kind should match original with empty message");
      Assert (To_String (Parsed.Message) = "",
              "Parsed Message should be empty");
   end Test_Format_Error_Empty_Message;

   --  Test: Parse_Error on non-Database_Error message returns Unknown
   procedure Test_Parse_Error_Non_Database_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      --  Simulate parsing a non-Database_Error exception message
      --  by calling Parse_Error with a string that doesn't match
      --  the [Kind|code] format. We need an Exception_Occurrence,
      --  so we raise and catch one.
      Parsed : DB.Error_Info;
   begin
      raise Constraint_Error with "something went wrong in the controller";
   exception
      when E : Constraint_Error =>
         Parsed := DB.Parse_Error (E);
         Assert (Parsed.Kind = DB.Unknown,
                 "Non-Database_Error message should parse as Unknown");
   end Test_Parse_Error_Non_Database_Error;

   --  Register all test routines
   overriding procedure Register_Tests (T : in out Database_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Classify_Error_Known_Codes'Access,
         "Classify_Error maps known SQLite codes to Error_Kind");
      Register_Routine
        (T, Test_Classify_Error_Code_1_Unknown'Access,
         "Classify_Error maps SQLITE_ERROR (code 1) to Unknown");
      Register_Routine
        (T, Test_Classify_Error_Unknown_Code'Access,
         "Classify_Error maps unrecognized code to Unknown");
      Register_Routine
        (T, Test_Format_Parse_Error_Roundtrip'Access,
         "Format_Error and Parse_Error round-trip correctly");
      Register_Routine
        (T, Test_Format_Error_Empty_Message'Access,
         "Format_Error handles empty message string");
      Register_Routine
        (T, Test_Parse_Error_Non_Database_Error'Access,
         "Parse_Error on non-Database_Error returns Unknown");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Database_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Database_Tests;
