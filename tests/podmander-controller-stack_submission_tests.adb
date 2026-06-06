--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Strings.Unbounded;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Controller.Stack_Submission;
with Podmander.Database;

package body Podmander.Controller.Stack_Submission_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Database;
   package Submission renames Podmander.Controller.Stack_Submission;
   package Svc_Repo renames Podmander.Controller.Service.Repository;
   package Cat_Repo renames Podmander.Controller.Service_Catalog.Repository;
   use type Submission.Submission_Error;

   type Stack_Submission_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Stack_Submission_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Stack_Submission"));

   overriding
   procedure Register_Tests (T : in out Stack_Submission_Test);

   -- Minimal valid TOML content
   Valid_TOML : constant String :=
     "[service.web]" & ASCII.LF
     & "image = ""nginx:latest""" & ASCII.LF;

   -- Invalid TOML syntax
   Invalid_TOML : constant String := "this is not valid toml";

   -- Valid TOML but missing [service] section
   No_Service_TOML : constant String :=
     "[database]" & ASCII.LF
     & "path = ""/data""" & ASCII.LF;

   ---------------------------------------------------
   -- Test_Submit_Happy_Path
   ---------------------------------------------------

   procedure Test_Submit_Happy_Path
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Submission.Submission_Result;
   begin
      Result := Submission.Submit (D, Valid_TOML);
      Assert (Result.Ok, "Submit should succeed for valid TOML");
      Assert (Result.Error = Submission.None, "Error should be None on success");
   end Test_Submit_Happy_Path;

   ---------------------------------------------------
   -- Test_Submit_Parse_Failed
   ---------------------------------------------------

   procedure Test_Submit_Parse_Failed
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Submission.Submission_Result;
   begin
      Result := Submission.Submit (D, Invalid_TOML);
      Assert (not Result.Ok, "Submit should fail for invalid TOML");
      Assert
        (Result.Error = Submission.Parse_Failed,
         "Error should be Parse_Failed");
   end Test_Submit_Parse_Failed;

   ---------------------------------------------------
   -- Test_Submit_Parse_Failed_No_Service_Section
   ---------------------------------------------------

   procedure Test_Submit_Parse_Failed_No_Service_Section
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Submission.Submission_Result;
   begin
      Result := Submission.Submit (D, No_Service_TOML);
      Assert (not Result.Ok, "Submit should fail when [service] is missing");
      Assert
        (Result.Error = Submission.Parse_Failed,
         "Error should be Parse_Failed for missing service section");
   end Test_Submit_Parse_Failed_No_Service_Section;

   ---------------------------------------------------
   -- Test_Submit_Registration_And_Schedule_Success
   ---------------------------------------------------

   procedure Test_Submit_Registration_And_Schedule_Success
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Submission.Submission_Result;
      Found  : Podmander.Controller.Service.Service;
      Cat    : Podmander.Controller.Service_Catalog_Entry;
   begin
      Result := Submission.Submit (D, Valid_TOML);
      Assert (Result.Ok, "Submit should succeed for valid TOML");

      -- Verify the service was registered
      Found := Svc_Repo.Get_By_Name (D, "web");
      Assert (To_String (Found.Name) = "web", "Service 'web' should exist");

      -- Verify a catalog entry was created
      Cat := Cat_Repo.Get_By_Service_Id (D, Found.Id);
      Assert
        (Cat.Target_Version = Podmander.Controller.Service_Version_Type (1),
         "Target_Version should be 1");
      Assert
        (Cat.State = Podmander.Controller.Pending,
         "State should be Pending");
   end Test_Submit_Registration_And_Schedule_Success;

   ---------------------------------------------------
   -- Test_Submit_Registration_Failed
   ---------------------------------------------------

   procedure Test_Submit_Registration_Failed
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Submission.Submission_Result;
   begin
      -- Drop the service_versions table so that Get_Latest_Version
      -- fails during registration. The Registrar catches this as
      -- Database_Error (non-Not_Found) and returns Ok = False.
      DB.Execute (D, "DROP TABLE service_versions");
      Result := Submission.Submit (D, Valid_TOML);
      Assert (not Result.Ok, "Submit should fail with missing table");
      Assert
        (Result.Error = Submission.Registration_Failed,
         "Error should be Registration_Failed");
   end Test_Submit_Registration_Failed;

   ------------------------------------
   -- Register tests
   ------------------------------------

   overriding
   procedure Register_Tests (T : in out Stack_Submission_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Submit_Happy_Path'Access,
         "Submit valid TOML succeeds with Ok = True");
      Register_Routine
        (T,
         Test_Submit_Parse_Failed'Access,
         "Submit invalid TOML returns Parse_Failed");
      Register_Routine
        (T,
         Test_Submit_Parse_Failed_No_Service_Section'Access,
         "Submit TOML without [service] returns Parse_Failed");
      Register_Routine
        (T,
         Test_Submit_Registration_And_Schedule_Success'Access,
         "Submit valid TOML registers service and creates catalog entry");
      Register_Routine
        (T,
         Test_Submit_Registration_Failed'Access,
         "Submit returns Registration_Failed on database error");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Stack_Submission_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Stack_Submission_Tests;
