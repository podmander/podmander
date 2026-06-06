--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Podctl.Client;
with Podmander.Podctl.Config;

package body Podmander.Podctl.Client_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Podctl.Client;

   type Client_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Client_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Podctl.Client"));

   overriding
   procedure Register_Tests (T : in out Client_Test);

   Fixture_Dir : constant String := "tests/fixtures/";

   --  A well-formed join token: PTKN- + 40-char key + - + 32-char secret.
   Valid_Token : constant String :=
     "PTKN-0123456789012345678901234567890123456789-"
     & "00000000000000000000000000000000";

   --  Token parsing: malformed token stops Deploy before opening a socket.
   procedure Test_Invalid_Token_Returns_Token_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cfg : constant Podmander.Podctl.Config.Connection_Config :=
        (Controller => To_Unbounded_String ("tcp://localhost:5555"),
         Token      => To_Unbounded_String ("not-a-valid-token"));
      Result : constant Deploy_Result :=
        Deploy (TOML_Path => Fixture_Dir & "valid.toml", Cfg => Cfg);
   begin
      Assert
        (Result.Outcome = Token_Error,
         "Malformed token should give Token_Error, got: "
         & Deploy_Outcome'Image (Result.Outcome));
   end Test_Invalid_Token_Returns_Token_Error;

   --  File liveness via Deploy: missing file is caught before the socket opens.
   procedure Test_Missing_File_Returns_File_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cfg : constant Podmander.Podctl.Config.Connection_Config :=
        (Controller => To_Unbounded_String ("tcp://localhost:5555"),
         Token      => To_Unbounded_String (Valid_Token));
      Result : constant Deploy_Result :=
        Deploy
          (TOML_Path => "/nonexistent/stack.toml",
           Cfg       => Cfg);
   begin
      Assert
        (Result.Outcome = File_Error,
         "Missing TOML file should give File_Error, got: "
         & Deploy_Outcome'Image (Result.Outcome));
   end Test_Missing_File_Returns_File_Error;

   --  File liveness via Deploy: empty file is caught before the socket opens.
   procedure Test_Empty_File_Returns_File_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cfg : constant Podmander.Podctl.Config.Connection_Config :=
        (Controller => To_Unbounded_String ("tcp://localhost:5555"),
         Token      => To_Unbounded_String (Valid_Token));
      Result : constant Deploy_Result :=
        Deploy
          (TOML_Path => Fixture_Dir & "empty.toml",
           Cfg       => Cfg);
   begin
      Assert
        (Result.Outcome = File_Error,
         "Empty TOML file should give File_Error, got: "
         & Deploy_Outcome'Image (Result.Outcome));
   end Test_Empty_File_Returns_File_Error;

   --  Check_TOML_File: non-existent path.
   procedure Test_Check_File_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Check_TOML_File ("/nonexistent/stack.toml") = Not_Found,
         "Non-existent path should return Not_Found");
   end Test_Check_File_Not_Found;

   --  Check_TOML_File: empty file.
   procedure Test_Check_File_Empty
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Check_TOML_File (Fixture_Dir & "empty.toml") = Empty,
         "Empty file should return Empty");
   end Test_Check_File_Empty;

   --  Check_TOML_File: non-empty readable file.
   procedure Test_Check_File_Ok
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Check_TOML_File (Fixture_Dir & "valid.toml") = Ok,
         "Non-empty readable file should return Ok");
   end Test_Check_File_Ok;

   --  Exit code mapping: Accepted maps to 0.
   procedure Test_Accepted_Exit_Code_Is_Zero
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Exit_Code_For (Accepted) = 0,
         "Accepted should map to exit code 0");
   end Test_Accepted_Exit_Code_Is_Zero;

   --  Exit code mapping: all failure outcomes map to non-zero codes.
   procedure Test_Failure_Exit_Codes_Are_Nonzero
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Exit_Code_For (Token_Error) /= 0,
         "Token_Error should map to non-zero exit code");
      Assert
        (Exit_Code_For (File_Error) /= 0,
         "File_Error should map to non-zero exit code");
      Assert
        (Exit_Code_For (Timeout) /= 0,
         "Timeout should map to non-zero exit code");
      Assert
        (Exit_Code_For (Rejected) /= 0,
         "Rejected should map to non-zero exit code");
   end Test_Failure_Exit_Codes_Are_Nonzero;

   --  Exit code mapping: each failure outcome maps to a distinct code.
   procedure Test_Failure_Exit_Codes_Are_Distinct
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Exit_Code_For (Token_Error) /= Exit_Code_For (File_Error),
         "Token_Error and File_Error should have distinct exit codes");
      Assert
        (Exit_Code_For (File_Error) /= Exit_Code_For (Timeout),
         "File_Error and Timeout should have distinct exit codes");
      Assert
        (Exit_Code_For (Timeout) /= Exit_Code_For (Rejected),
         "Timeout and Rejected should have distinct exit codes");
   end Test_Failure_Exit_Codes_Are_Distinct;

   overriding
   procedure Register_Tests (T : in out Client_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Invalid_Token_Returns_Token_Error'Access,
         "Malformed token returns Token_Error without opening a socket");
      Register_Routine
        (T,
         Test_Missing_File_Returns_File_Error'Access,
         "Missing TOML file returns File_Error without opening a socket");
      Register_Routine
        (T,
         Test_Empty_File_Returns_File_Error'Access,
         "Empty TOML file returns File_Error without opening a socket");
      Register_Routine
        (T,
         Test_Check_File_Not_Found'Access,
         "Check_TOML_File returns Not_Found for non-existent path");
      Register_Routine
        (T, Test_Check_File_Empty'Access, "Check_TOML_File returns Empty for empty file");
      Register_Routine
        (T, Test_Check_File_Ok'Access, "Check_TOML_File returns Ok for non-empty readable file");
      Register_Routine
        (T,
         Test_Accepted_Exit_Code_Is_Zero'Access,
         "Accepted maps to exit code 0");
      Register_Routine
        (T,
         Test_Failure_Exit_Codes_Are_Nonzero'Access,
         "All failure outcomes map to non-zero exit codes");
      Register_Routine
        (T,
         Test_Failure_Exit_Codes_Are_Distinct'Access,
         "Each failure outcome has a distinct exit code");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Client_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Podctl.Client_Tests;
