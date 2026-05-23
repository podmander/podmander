--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;
with Podmander.Config;
with Podmander.Controller;
with Podmander.Controller.Service.Repository;
with Podmander.Database;

package body Podmander.Controller.Service.Repository_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB   renames Podmander.Database;
   package Repo renames Podmander.Controller.Service.Repository;

   use type DB.Error_Kind;

   type Repository_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name
     (T : Repository_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Service.Repository"));

   overriding procedure Register_Tests (T : in out Repository_Test);

   My_Service : constant String := "web-app";
   My_Image   : constant String := "nginx:1.25";
   My_Desc    : constant String := "Web server";
   My_Wanted  : constant String := "multi-user.target";

   --  Helper: build a Service_Version with the given version number
   function Make_Version (V : Positive) return Podmander.Controller.Service_Version
   is
      Result : Podmander.Controller.Service_Version;
   begin
      Result.Service_Name  := To_Unbounded_String (My_Service);
      Result.Version       := V;
      Result.Image         := To_Unbounded_String (My_Image);
      Result.Description   := To_Unbounded_String (My_Desc);
      Result.Wanted_By     := To_Unbounded_String (My_Wanted);
      Result.Created_At    := Ada.Calendar.Clock;
      --  Add one env var
      Result.Env (1) :=
        (Key => To_Unbounded_String ("FOO"),
         Value => To_Unbounded_String ("bar"));
      Result.Env_Count := 1;
      --  Add one port mapping
      Result.Ports (1) := (Host => 8080, Container => 80);
      Result.Ports_Count := 1;
      --  Add one volume mapping
      Result.Volumes (1) :=
        (Host      => To_Unbounded_String ("/host/data"),
         Container => To_Unbounded_String ("/container/data"));
      Result.Volumes_Count := 1;
      return Result;
   end Make_Version;

   --  Format time as ISO 8601 for string comparison
   function Format_Time (T : Ada.Calendar.Time) return String is
      Raw : constant String := Ada.Calendar.Formatting.Image (T);
   begin
      return Raw (1 .. 10) & "T" & Raw (12 .. 19) & "Z";
   end Format_Time;

   procedure Test_Create_Version
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      SV   : Podmander.Controller.Service_Version := Make_Version (1);
      Loaded : Podmander.Controller.Service_Version;
   begin
      Repo.Create_Version (D, SV);
      Loaded := Repo.Get_Version (D, My_Service, 1);
      Assert (To_String (Loaded.Service_Name) = My_Service,
              "Service_Name should match");
      Assert (To_String (Loaded.Image) = My_Image,
              "Image should match");
      Assert (Loaded.Version = 1,
              "Version should be 1");
      Assert (To_String (Loaded.Description) = My_Desc,
              "Description should match");
      Assert (To_String (Loaded.Wanted_By) = My_Wanted,
              "Wanted_By should match");
      Assert (Loaded.Env_Count = 1,
              "Should have 1 env var");
      Assert (To_String (Loaded.Env (1).Key) = "FOO",
              "Env key should match");
      Assert (To_String (Loaded.Env (1).Value) = "bar",
              "Env value should match");
      Assert (Loaded.Ports_Count = 1,
              "Should have 1 port mapping");
      Assert (Loaded.Ports (1).Host = 8080,
              "Port host should match");
      Assert (Loaded.Ports (1).Container = 80,
              "Port container should match");
      Assert (Loaded.Volumes_Count = 1,
              "Should have 1 volume mapping");
      Assert (To_String (Loaded.Volumes (1).Host) = "/host/data",
              "Volume host should match");
      Assert (To_String (Loaded.Volumes (1).Container) = "/container/data",
              "Volume container should match");
      Assert (Format_Time (Loaded.Created_At) = Format_Time (SV.Created_At),
              "Created_At should match");
   end Test_Create_Version;

   procedure Test_Create_Version_Duplicate_Raises
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      SV        : Podmander.Controller.Service_Version := Make_Version (1);
      Got_Error : Boolean := False;
   begin
      Repo.Create_Version (D, SV);
      begin
         Repo.Create_Version (D, SV);
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert (Err.Kind = DB.Constraint_Violation,
                       "Duplicate should raise Constraint_Violation");
               Got_Error := True;
            end;
      end;
      Assert (Got_Error,
              "Duplicate version should have raised Database_Error");
   end Test_Create_Version_Duplicate_Raises;

   procedure Test_Get_Version_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      Got_Error : Boolean := False;
   begin
      begin
         declare
            Ignored : Podmander.Controller.Service_Version :=
              Repo.Get_Version (D, "nonexistent", 1);
         begin
            null;
            pragma Unreferenced (Ignored);
         end;
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert (Err.Kind = DB.Not_Found,
                       "Get_Version on unknown should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert (Got_Error,
              "Get_Version on unknown should have raised Database_Error");
   end Test_Get_Version_Not_Found;

   procedure Test_Get_Latest_Version
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      SV1    : Podmander.Controller.Service_Version := Make_Version (1);
      SV2    : Podmander.Controller.Service_Version := Make_Version (2);
      SV3    : Podmander.Controller.Service_Version := Make_Version (3);
      Latest : Podmander.Controller.Service_Version;
   begin
      SV2.Image := To_Unbounded_String ("nginx:1.26");
      SV3.Image := To_Unbounded_String ("nginx:1.27");

      Repo.Create_Version (D, SV1);
      Repo.Create_Version (D, SV2);
      Repo.Create_Version (D, SV3);

      Latest := Repo.Get_Latest_Version (D, My_Service);
      Assert (Latest.Version = 3,
              "Latest version should be 3");
      Assert (To_String (Latest.Image) = "nginx:1.27",
              "Latest image should match version 3");
   end Test_Get_Latest_Version;

   procedure Test_Get_Latest_Version_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      Got_Error : Boolean := False;
   begin
      begin
         declare
            Ignored : Podmander.Controller.Service_Version :=
              Repo.Get_Latest_Version (D, "nonexistent");
         begin
            null;
            pragma Unreferenced (Ignored);
         end;
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert (Err.Kind = DB.Not_Found,
                       "Get_Latest_Version on unknown should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert (Got_Error,
              "Get_Latest_Version on unknown should have raised Database_Error");
   end Test_Get_Latest_Version_Not_Found;

   procedure Test_Create_Version_With_Empty_Arrays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      SV   : Podmander.Controller.Service_Version := Make_Version (1);
      Loaded : Podmander.Controller.Service_Version;
   begin
      SV.Env_Count     := 0;
      SV.Ports_Count   := 0;
      SV.Volumes_Count := 0;

      Repo.Create_Version (D, SV);
      Loaded := Repo.Get_Version (D, My_Service, 1);
      Assert (Loaded.Env_Count = 0,
              "Env_Count should be 0");
      Assert (Loaded.Ports_Count = 0,
              "Ports_Count should be 0");
      Assert (Loaded.Volumes_Count = 0,
              "Volumes_Count should be 0");
   end Test_Create_Version_With_Empty_Arrays;

   overriding procedure Register_Tests (T : in out Repository_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Create_Version'Access,
         "Create a service version and verify it persists with all fields");
      Register_Routine
        (T, Test_Create_Version_Duplicate_Raises'Access,
         "Create duplicate version raises Constraint_Violation");
      Register_Routine
        (T, Test_Get_Version_Not_Found'Access,
         "Get_Version on nonexistent version raises Not_Found");
      Register_Routine
        (T, Test_Get_Latest_Version'Access,
         "Get_Latest_Version returns the highest version");
      Register_Routine
        (T, Test_Get_Latest_Version_Not_Found'Access,
         "Get_Latest_Version on unknown service raises Not_Found");
      Register_Routine
        (T, Test_Create_Version_With_Empty_Arrays'Access,
         "Create version with empty env/ports/volumes arrays");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Repository_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Service.Repository_Tests;
