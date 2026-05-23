--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Strings.Unbounded;
with Podmander.Config;
with Podmander.Controller;
with Podmander.Controller.Registrar;
with Podmander.Controller.Service.Repository;
with Podmander.Database;

package body Podmander.Controller.Registrar_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Database;
   package Registrar renames Podmander.Controller.Registrar;
   package Repo renames Podmander.Controller.Service.Repository;
   use type Registrar.Register_Error;

   type Registrar_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Registrar_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Registrar"));

   overriding
   procedure Register_Tests (T : in out Registrar_Test);

   --  Constants for test service definitions
   Service_Name   : constant String := "web-app";
   Service_Image  : constant String := "nginx:1.25";
   Service_Desc   : constant String := "Web server";
   Service_Wanted : constant String := "multi-user.target";

   --  Helper: build a minimal Service_Definition
   function Make_Service_Definition
     (Name   : String;
      Image  : String;
      Desc   : String;
      Wanted : String)
      return Podmander.Config.Service_Definition
   is
      Result : Podmander.Config.Service_Definition;
   begin
      Result.Name := To_Unbounded_String (Name);
      Result.Image := To_Unbounded_String (Image);
      Result.Description := To_Unbounded_String (Desc);
      Result.WantedBy := To_Unbounded_String (Wanted);
      Result.Env_Count := 0;
      Result.Ports_Count := 0;
      Result.Volumes_Count := 0;
      return Result;
   end Make_Service_Definition;

   ---------------------------------------
   --  Test: Register a brand new service
   ---------------------------------------

   procedure Test_Register_New_Service
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      ASD    : constant Podmander.Config.Service_Definition :=
        Make_Service_Definition
          (Service_Name, Service_Image, Service_Desc, Service_Wanted);
      Result : Registrar.Register_Result;
      Found  : Podmander.Controller.Service.Service;
   begin
      Result := Registrar.Register (D, ASD);
      Assert (Result.Ok, "Register should succeed for new service");
      Assert
        (Result.Error = Registrar.None,
         "Error should be None on success");

      --  Verify service row exists
      Found := Repo.Get_By_Name (D, Service_Name);
      Assert
        (To_String (Found.Name) = Service_Name,
         "Service name should match");
      Assert
        (Found.Id = Result.Version.Service_Id,
         "Service id should match in version");

      --  Verify version is 1
      Assert
        (Result.Version.Version = 1,
         "First version should be 1");
   end Test_Register_New_Service;

   ------------------------------------------------
   --  Test: Register existing service increments version
   ------------------------------------------------

   procedure Test_Register_Existing_Service_Increment_Version
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      ASD     : constant Podmander.Config.Service_Definition :=
        Make_Service_Definition
          (Service_Name, Service_Image, Service_Desc, Service_Wanted);
      Result1 : Registrar.Register_Result;
      Result2 : Registrar.Register_Result;
   begin
      Result1 := Registrar.Register (D, ASD);
      Assert (Result1.Ok, "First register should succeed");
      Assert (Result1.Version.Version = 1, "First version should be 1");

      Result2 := Registrar.Register (D, ASD);
      Assert (Result2.Ok, "Second register should succeed");
      Assert (Result2.Version.Version = 2, "Second version should be 2");

      --  Both should have the same Service_Id
      Assert
        (Result1.Version.Service_Id = Result2.Version.Service_Id,
         "Both versions should reference the same service");
   end Test_Register_Existing_Service_Increment_Version;

   -------------------------------------------------
   --  Test: Idempotent service creation
   -------------------------------------------------

   procedure Test_Register_Idempotent_Service_Creation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      ASD     : constant Podmander.Config.Service_Definition :=
        Make_Service_Definition
          (Service_Name, Service_Image, Service_Desc, Service_Wanted);
      Result1 : Registrar.Register_Result;
      Result2 : Registrar.Register_Result;
   begin
      Result1 := Registrar.Register (D, ASD);
      Assert (Result1.Ok, "First register should succeed");

      Result2 := Registrar.Register (D, ASD);
      Assert (Result2.Ok, "Second register should succeed");

      --  Same service id both times
      Assert
        (Result1.Version.Service_Id = Result2.Version.Service_Id,
         "Register twice should return same service id");

      --  Only one services row exists
      Assert
        (Result1.Version.Service_Id > 0,
         "Service id should be positive");
   end Test_Register_Idempotent_Service_Creation;

   ------------------------------------
   --  Register tests
   ------------------------------------

   overriding
   procedure Register_Tests (T : in out Registrar_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Register_New_Service'Access,
         "Register a new service creates services row and version 1");
      Register_Routine
        (T,
         Test_Register_Existing_Service_Increment_Version'Access,
         "Register same service twice increments version to 2");
      Register_Routine
        (T,
         Test_Register_Idempotent_Service_Creation'Access,
         "Register same service twice returns same service id");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Registrar_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Registrar_Tests;
