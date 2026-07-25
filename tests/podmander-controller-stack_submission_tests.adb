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

   type Stack_Submission_Test is new AUnit.Test_Cases.Test_Case
   with null record;

   overriding
   function Name (T : Stack_Submission_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Stack_Submission"));

   overriding
   procedure Register_Tests (T : in out Stack_Submission_Test);

   -- Minimal valid TOML content
   Valid_TOML : constant String :=
     "[service.web]" & ASCII.LF & "image = ""nginx:latest""" & ASCII.LF;

   -- Invalid TOML syntax
   Invalid_TOML : constant String := "this is not valid toml";

   -- Valid TOML but missing [service] section
   No_Service_TOML : constant String :=
     "[database]" & ASCII.LF & "path = ""/data""" & ASCII.LF;

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
      Assert
        (Result.Error = Submission.None, "Error should be None on success");
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
        (Cat.State = Podmander.Controller.Pending, "State should be Pending");
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

   procedure Test_Submit_Rolls_Back_On_Late_Scheduler_Trigger
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Submission.Submission_Result;
   begin
      DB.Execute
        (D,
         "CREATE TRIGGER reject_catalog_insert AFTER INSERT ON service_catalog "
         & "BEGIN SELECT RAISE(ABORT, 'scheduler persistence rejected'); END;");
      Result := Submission.Submit (D, Valid_TOML);
      Assert
        (not Result.Ok, "late scheduler failure should reject submission");
      declare
         Query : DB.Query_Handle :=
           DB.Prepare (D, "SELECT COUNT(*) FROM services");
      begin
         Assert (DB.Step (Query), "services count should be queryable");
         Assert
           (DB.Column_Int (Query, 0) = 0,
            "service registration must roll back");
      end;
      declare
         Query : DB.Query_Handle :=
           DB.Prepare (D, "SELECT COUNT(*) FROM service_versions");
      begin
         Assert (DB.Step (Query), "service version count should be queryable");
         Assert
           (DB.Column_Int (Query, 0) = 0,
            "service version persistence must roll back");
      end;
      declare
         Query : DB.Query_Handle :=
           DB.Prepare (D, "SELECT COUNT(*) FROM service_catalog");
      begin
         Assert (DB.Step (Query), "catalog count should be queryable");
         Assert
           (DB.Column_Int (Query, 0) = 0,
            "catalog persistence must roll back");
      end;
   end Test_Submit_Rolls_Back_On_Late_Scheduler_Trigger;

   procedure Test_Submit_Fails_Closed_On_Malformed_Active_Ports
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      First  : Submission.Submission_Result;
      Second : Submission.Submission_Result;
      Web    : Podmander.Controller.Service.Service;
   begin
      First := Submission.Submit (D, Valid_TOML);
      Assert (First.Ok, "fixture service should submit");
      Web := Svc_Repo.Get_By_Name (D, "web");
      DB.Execute
        (D,
         "UPDATE service_versions SET ports = 'not-json'"
         & " WHERE service_id = "
         & Web.Id'Image
         & " AND version = 1");
      Second :=
        Submission.Submit
          (D,
           "[service.other]"
           & ASCII.LF
           & "image = ""nginx:latest"""
           & ASCII.LF
           & "ports = [""8080:80""]"
           & ASCII.LF);
      Assert
        (not Second.Ok,
         "reservation parsing must reject malformed active port JSON");
   end Test_Submit_Fails_Closed_On_Malformed_Active_Ports;

   procedure Test_Current_Version_Remains_Reserved_Beside_Target
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      First   : Submission.Submission_Result;
      Target  : Submission.Submission_Result;
      Other   : Submission.Submission_Result;
      Web     : Podmander.Controller.Service.Service;
      Catalog : Podmander.Controller.Service_Catalog_Entry;
   begin
      First :=
        Submission.Submit
          (D,
           "[service.web]"
           & ASCII.LF
           & "image = ""nginx:old"""
           & ASCII.LF
           & "ports = [""8080:80""]"
           & ASCII.LF);
      Assert (First.Ok, "initial service should submit");
      Web := Svc_Repo.Get_By_Name (D, "web");
      Catalog := Cat_Repo.Get_By_Service_Id (D, Web.Id);
      Assert
        (Cat_Repo.Update_On_Success (D, Catalog.Id, 1),
         "initial service should become current");
      Target :=
        Submission.Submit
          (D,
           "[service.web]"
           & ASCII.LF
           & "image = ""nginx:new"""
           & ASCII.LF
           & "ports = [""9090:80""]"
           & ASCII.LF);
      Assert (Target.Ok, "new target version should submit");
      Other :=
        Submission.Submit
          (D,
           "[service.other]"
           & ASCII.LF
           & "image = ""nginx:other"""
           & ASCII.LF
           & "ports = [""8080:80""]"
           & ASCII.LF);
      Assert (not Other.Ok, "another service must not reuse current port");
      Assert
        (To_String (Other.Message)
         = "Host port '8080' is already reserved by service 'web'",
         "current-version reservation message is precise");
   end Test_Current_Version_Remains_Reserved_Beside_Target;

   procedure Test_Historical_Version_Releases_Reservation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      First   : Submission.Submission_Result;
      Target  : Submission.Submission_Result;
      Other   : Submission.Submission_Result;
      Web     : Podmander.Controller.Service.Service;
      Catalog : Podmander.Controller.Service_Catalog_Entry;
   begin
      First :=
        Submission.Submit
          (D,
           "[service.web]"
           & ASCII.LF
           & "image = ""nginx:old"""
           & ASCII.LF
           & "ports = [""8080:80""]"
           & ASCII.LF);
      Assert (First.Ok, "initial service should submit");
      Web := Svc_Repo.Get_By_Name (D, "web");
      Catalog := Cat_Repo.Get_By_Service_Id (D, Web.Id);
      Assert
        (Cat_Repo.Update_On_Success (D, Catalog.Id, 1),
         "initial service should become current");
      Target :=
        Submission.Submit
          (D,
           "[service.web]"
           & ASCII.LF
           & "image = ""nginx:new"""
           & ASCII.LF
           & "ports = [""9090:80""]"
           & ASCII.LF);
      Assert (Target.Ok, "new target version should submit");
      Assert
        (Cat_Repo.Update_On_Success (D, Catalog.Id, 2),
         "new target should become current");
      Other :=
        Submission.Submit
          (D,
           "[service.other]"
           & ASCII.LF
           & "image = ""nginx:other"""
           & ASCII.LF
           & "ports = [""8080:80""]"
           & ASCII.LF);
      Assert (Other.Ok, "historical port should no longer be reserved");
   end Test_Historical_Version_Releases_Reservation;

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
      Register_Routine
        (T,
         Test_Submit_Rolls_Back_On_Late_Scheduler_Trigger'Access,
         "Submit rolls back all writes after late scheduler failure");
      Register_Routine
        (T,
         Test_Submit_Fails_Closed_On_Malformed_Active_Ports'Access,
         "Submit fails closed on malformed active port JSON");
      Register_Routine
        (T,
         Test_Current_Version_Remains_Reserved_Beside_Target'Access,
         "Current version remains reserved while newer target exists");
      Register_Routine
        (T,
         Test_Historical_Version_Releases_Reservation'Access,
         "Historical version releases its host-port reservation");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Stack_Submission_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Stack_Submission_Tests;
