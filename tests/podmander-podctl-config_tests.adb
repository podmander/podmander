--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Podctl.Config;

package body Podmander.Podctl.Config_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   type Config_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Config_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Podctl.Config"));

   overriding
   procedure Register_Tests (T : in out Config_Test);

   Fixture_Dir : constant String := "tests/fixtures/";

   function Fixture_Path (File : String) return String
   is (Fixture_Dir & File);

   --  No file, no flags: endpoint defaults, token missing => error
   procedure Test_Missing_Token_Is_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Podctl.Config.Load_Result :=
        Podmander.Podctl.Config.Load
          (Config_File => "/nonexistent/podctl.toml");
   begin
      Assert (not Result.Success, "Load without token should fail");
      Assert
        (To_String (Result.Message) = "token is required",
         "Error message should say 'token is required', got: "
         & To_String (Result.Message));
   end Test_Missing_Token_Is_Error;

   --  No file, token flag provided: succeeds with default endpoint
   procedure Test_Default_Controller_When_No_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Podctl.Config.Load_Result :=
        Podmander.Podctl.Config.Load
          (Config_File    => "/nonexistent/podctl.toml",
           Token_Override => "test-token");
   begin
      Assert (Result.Success, "Load with token flag should succeed");
      Assert
        (To_String (Result.Value.Controller)
         = Podmander.Podctl.Config.Default_Controller,
         "Controller should default to "
         & Podmander.Podctl.Config.Default_Controller);
   end Test_Default_Controller_When_No_File;

   --  Missing config file is silently skipped, not an error
   procedure Test_Missing_File_Is_Not_Fatal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Podctl.Config.Load_Result :=
        Podmander.Podctl.Config.Load
          (Config_File    => "/nonexistent/podctl.toml",
           Token_Override => "test-token");
   begin
      Assert (Result.Success, "Missing config file should not be fatal");
   end Test_Missing_File_Is_Not_Fatal;

   --  File sets both endpoint and token
   procedure Test_File_Loads_Values
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Podctl.Config.Load_Result :=
        Podmander.Podctl.Config.Load
          (Config_File => Fixture_Path ("podctl_with_token.toml"));
   begin
      Assert (Result.Success, "Load from fixture file should succeed");
      Assert
        (To_String (Result.Value.Controller) = "tcp://filehost:5555",
         "Controller should come from file");
      Assert
        (To_String (Result.Value.Token) = "file-token",
         "Token should come from file");
   end Test_File_Loads_Values;

   --  Flags override file values (file < flags precedence)
   procedure Test_Flags_Override_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Podctl.Config.Load_Result :=
        Podmander.Podctl.Config.Load
          (Config_File         => Fixture_Path ("podctl_with_token.toml"),
           Controller_Override => "tcp://override:9999",
           Token_Override      => "flag-token");
   begin
      Assert (Result.Success, "Load with overrides should succeed");
      Assert
        (To_String (Result.Value.Controller) = "tcp://override:9999",
         "Controller flag should override file value");
      Assert
        (To_String (Result.Value.Token) = "flag-token",
         "Token flag should override file value");
   end Test_Flags_Override_File;

   --  Controller flag alone overrides file, file token still used
   procedure Test_Controller_Flag_Overrides_File_Controller
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Podctl.Config.Load_Result :=
        Podmander.Podctl.Config.Load
          (Config_File         => Fixture_Path ("podctl_with_token.toml"),
           Controller_Override => "tcp://override:9999");
   begin
      Assert (Result.Success, "Load should succeed with file token");
      Assert
        (To_String (Result.Value.Controller) = "tcp://override:9999",
         "Controller flag should override file controller");
      Assert
        (To_String (Result.Value.Token) = "file-token",
         "File token should be used when no token flag");
   end Test_Controller_Flag_Overrides_File_Controller;

   overriding
   procedure Register_Tests (T : in out Config_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Missing_Token_Is_Error'Access,
         "Missing token with no file and no flag is an error");
      Register_Routine
        (T,
         Test_Default_Controller_When_No_File'Access,
         "Endpoint defaults to tcp://localhost:5555 when no file");
      Register_Routine
        (T,
         Test_Missing_File_Is_Not_Fatal'Access,
         "Missing config file is not fatal");
      Register_Routine
        (T, Test_File_Loads_Values'Access, "File sets controller and token");
      Register_Routine
        (T,
         Test_Flags_Override_File'Access,
         "Flags override file values (file < flags precedence)");
      Register_Routine
        (T,
         Test_Controller_Flag_Overrides_File_Controller'Access,
         "Controller flag overrides file controller, file token still used");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Config_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Podctl.Config_Tests;
