--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;
with Podmander.Controller.Service.Repository;
with Podmander.Database;

package body Podmander.Controller.Service.Repository_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Database;
   package Repo renames Podmander.Controller.Service.Repository;

   use type DB.Error_Kind;

   type Repository_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Repository_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Service.Repository"));

   overriding
   procedure Register_Tests (T : in out Repository_Test);

   My_Service : constant String := "web-app";
   My_Image   : constant String := "nginx:1.25";
   My_Desc    : constant String := "Web server";
   My_Wanted  : constant String := "multi-user.target";

   -- Helper: build a Service_Version with the given version number and service_id
   function Make_Version
     (V          : Podmander.Controller.Service_Version_Type;
      Service_Id : Podmander.Controller.Service_Id_Type)
      return Podmander.Controller.Service_Version
   is
      Result : Podmander.Controller.Service_Version;
   begin
      Result.Id := 0;
      Result.Service_Id := Service_Id;
      Result.Version := V;
      Result.Image := To_Unbounded_String (My_Image);
      Result.Description := To_Unbounded_String (My_Desc);
      Result.Wanted_By := To_Unbounded_String (My_Wanted);
      Result.Created_At := Ada.Calendar.Clock;
      -- Add one env var
      Result.Env (1) :=
        (Key   => To_Unbounded_String ("FOO"),
         Value => To_Unbounded_String ("bar"));
      Result.Env_Count := 1;
      -- Add one port mapping
      Result.Ports (1) := (Host => 8080, Container => 80);
      Result.Ports_Count := 1;
      -- Add one volume mapping
      Result.Volumes (1) :=
        (Host      => To_Unbounded_String ("/host/data"),
         Container => To_Unbounded_String ("/container/data"));
      Result.Volumes_Count := 1;
      return Result;
   end Make_Version;

   -- Format time as ISO 8601 for string comparison
   function Format_Time (T : Ada.Calendar.Time) return String is
      Raw : constant String := Ada.Calendar.Formatting.Image (T);
   begin
      return Raw (1 .. 10) & "T" & Raw (12 .. 19) & "Z";
   end Format_Time;

   procedure Test_Create_Version (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Svc    : constant Podmander.Controller.Service.Service :=
        Repo.Create (D, My_Service);
      SV     : constant Podmander.Controller.Service_Version :=
        Make_Version (1, Svc.Id);
      Loaded : Podmander.Controller.Service_Version;
   begin
      Repo.Create_Version (D, SV);
      Loaded :=
        Repo.Get_Version
          (D, Svc.Id, Podmander.Controller.Service_Version_Type (1));
      Assert (Loaded.Id > 0, "Id should be positive after insert");
      Assert (Loaded.Service_Id = Svc.Id, "Service_Id should match");
      Assert (To_String (Loaded.Image) = My_Image, "Image should match");
      Assert
        (Loaded.Version = Podmander.Controller.Service_Version_Type (1),
         "Version should be 1");
      Assert
        (To_String (Loaded.Description) = My_Desc, "Description should match");
      Assert
        (To_String (Loaded.Wanted_By) = My_Wanted, "Wanted_By should match");
      Assert (Loaded.Env_Count = 1, "Should have 1 env var");
      Assert (To_String (Loaded.Env (1).Key) = "FOO", "Env key should match");
      Assert
        (To_String (Loaded.Env (1).Value) = "bar", "Env value should match");
      Assert (Loaded.Ports_Count = 1, "Should have 1 port mapping");
      Assert (Loaded.Ports (1).Host = 8080, "Port host should match");
      Assert (Loaded.Ports (1).Container = 80, "Port container should match");
      Assert (Loaded.Volumes_Count = 1, "Should have 1 volume mapping");
      Assert
        (To_String (Loaded.Volumes (1).Host) = "/host/data",
         "Volume host should match");
      Assert
        (To_String (Loaded.Volumes (1).Container) = "/container/data",
         "Volume container should match");
      Assert
        (Format_Time (Loaded.Created_At) = Format_Time (SV.Created_At),
         "Created_At should match");
   end Test_Create_Version;

   procedure Test_Create_Version_Duplicate_Raises
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      Svc       : constant Podmander.Controller.Service.Service :=
        Repo.Create (D, My_Service);
      SV        : constant Podmander.Controller.Service_Version :=
        Make_Version (1, Svc.Id);
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
               Assert
                 (Err.Kind = DB.Constraint_Violation,
                  "Duplicate should raise Constraint_Violation");
               Got_Error := True;
            end;
      end;
      Assert
        (Got_Error, "Duplicate version should have raised Database_Error");
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
              Repo.Get_Version
                (D,
                 Podmander.Controller.Service_Id_Type (999),
                 Podmander.Controller.Service_Version_Type (1));
         begin
            null;
            pragma Unreferenced (Ignored);
         end;
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert
                 (Err.Kind = DB.Not_Found,
                  "Get_Version on unknown should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert
        (Got_Error,
         "Get_Version on unknown should have raised Database_Error");
   end Test_Get_Version_Not_Found;

   procedure Test_Get_Latest_Version
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Svc    : constant Podmander.Controller.Service.Service :=
        Repo.Create (D, My_Service);
      SV1    : constant Podmander.Controller.Service_Version :=
        Make_Version (1, Svc.Id);
      SV2    : Podmander.Controller.Service_Version :=
        Make_Version (2, Svc.Id);
      SV3    : Podmander.Controller.Service_Version :=
        Make_Version (3, Svc.Id);
      Latest : Podmander.Controller.Service_Version;
   begin
      SV2.Image := To_Unbounded_String ("nginx:1.26");
      SV3.Image := To_Unbounded_String ("nginx:1.27");

      Repo.Create_Version (D, SV1);
      Repo.Create_Version (D, SV2);
      Repo.Create_Version (D, SV3);

      Latest := Repo.Get_Latest_Version (D, Svc.Id);
      Assert
        (Latest.Version = Podmander.Controller.Service_Version_Type (3),
         "Latest version should be 3");
      Assert
        (To_String (Latest.Image) = "nginx:1.27",
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
              Repo.Get_Latest_Version
                (D, Podmander.Controller.Service_Id_Type (999));
         begin
            null;
            pragma Unreferenced (Ignored);
         end;
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert
                 (Err.Kind = DB.Not_Found,
                  "Get_Latest_Version on unknown should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert
        (Got_Error,
         "Get_Latest_Version on unknown should have raised Database_Error");
   end Test_Get_Latest_Version_Not_Found;

   procedure Test_Create_Version_With_Empty_Arrays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Svc    : constant Podmander.Controller.Service.Service :=
        Repo.Create (D, My_Service);
      SV     : Podmander.Controller.Service_Version :=
        Make_Version (1, Svc.Id);
      Loaded : Podmander.Controller.Service_Version;
   begin
      SV.Env_Count := 0;
      SV.Ports_Count := 0;
      SV.Volumes_Count := 0;

      Repo.Create_Version (D, SV);
      Loaded :=
        Repo.Get_Version
          (D, Svc.Id, Podmander.Controller.Service_Version_Type (1));
      Assert (Loaded.Env_Count = 0, "Env_Count should be 0");
      Assert (Loaded.Ports_Count = 0, "Ports_Count should be 0");
      Assert (Loaded.Volumes_Count = 0, "Volumes_Count should be 0");
   end Test_Create_Version_With_Empty_Arrays;

   ------------------------------------
   -- Service table repository tests --
   ------------------------------------

   My_Service_Name : constant String := "my-service";

   procedure Test_Service_Create (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Created : Podmander.Controller.Service.Service;
   begin
      Created := Repo.Create (D, My_Service_Name);
      Assert (Created.Id > 0, "Service id should be positive");
      Assert
        (To_String (Created.Name) = My_Service_Name,
         "Service name should match");
   end Test_Service_Create;

   procedure Test_Service_Create_Idempotent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      First  : Podmander.Controller.Service.Service;
      Second : Podmander.Controller.Service.Service;
   begin
      First := Repo.Create (D, My_Service_Name);
      Second := Repo.Create (D, My_Service_Name);
      Assert (First.Id = Second.Id, "Same name should return same id");
      Assert
        (To_String (Second.Name) = My_Service_Name,
         "Service name should match on second create");
   end Test_Service_Create_Idempotent;

   procedure Test_Service_Get_By_Name
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Created : Podmander.Controller.Service.Service;
      Found   : Podmander.Controller.Service.Service;
   begin
      Created := Repo.Create (D, My_Service_Name);
      Found := Repo.Get_By_Name (D, My_Service_Name);
      Assert (Found.Id = Created.Id, "Get_By_Name should return same id");
      Assert
        (To_String (Found.Name) = My_Service_Name,
         "Get_By_Name should return same name");
   end Test_Service_Get_By_Name;

   procedure Test_Service_Get_By_Name_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      Got_Error : Boolean := False;
   begin
      begin
         declare
            Ignored : Podmander.Controller.Service.Service :=
              Repo.Get_By_Name (D, "nonexistent");
         begin
            null;
            pragma Unreferenced (Ignored);
         end;
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert
                 (Err.Kind = DB.Not_Found,
                  "Get_By_Name on unknown should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert
        (Got_Error,
         "Get_By_Name on unknown should have raised Database_Error");
   end Test_Service_Get_By_Name_Not_Found;

   procedure Test_Service_Get_By_Id
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Created : Podmander.Controller.Service.Service;
      Found   : Podmander.Controller.Service.Service;
   begin
      Created := Repo.Create (D, My_Service_Name);
      Found := Repo.Get_By_Id (D, Created.Id);
      Assert (Found.Id = Created.Id, "Get_By_Id should return same id");
      Assert
        (To_String (Found.Name) = My_Service_Name,
         "Get_By_Id should return same name");
   end Test_Service_Get_By_Id;

   procedure Test_Service_Get_By_Id_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      Got_Error : Boolean := False;
   begin
      begin
         declare
            Ignored : Podmander.Controller.Service.Service :=
              Repo.Get_By_Id (D, Podmander.Controller.Service_Id_Type (999));
         begin
            null;
            pragma Unreferenced (Ignored);
         end;
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert
                 (Err.Kind = DB.Not_Found,
                  "Get_By_Id on unknown should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert
        (Got_Error, "Get_By_Id on unknown should have raised Database_Error");
   end Test_Service_Get_By_Id_Not_Found;

   overriding
   procedure Register_Tests (T : in out Repository_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Create_Version'Access,
         "Create a service version and verify it persists with all fields");
      Register_Routine
        (T,
         Test_Create_Version_Duplicate_Raises'Access,
         "Create duplicate version raises Constraint_Violation");
      Register_Routine
        (T,
         Test_Get_Version_Not_Found'Access,
         "Get_Version on nonexistent version raises Not_Found");
      Register_Routine
        (T,
         Test_Get_Latest_Version'Access,
         "Get_Latest_Version returns the highest version");
      Register_Routine
        (T,
         Test_Get_Latest_Version_Not_Found'Access,
         "Get_Latest_Version on unknown service raises Not_Found");
      Register_Routine
        (T,
         Test_Create_Version_With_Empty_Arrays'Access,
         "Create version with empty env/ports/volumes arrays");
      Register_Routine
        (T,
         Test_Service_Create'Access,
         "Create a new service and verify id and name");
      Register_Routine
        (T,
         Test_Service_Create_Idempotent'Access,
         "Create same service twice returns same id");
      Register_Routine
        (T,
         Test_Service_Get_By_Name'Access,
         "Get service by name returns correct fields");
      Register_Routine
        (T,
         Test_Service_Get_By_Name_Not_Found'Access,
         "Get service by unknown name raises Not_Found");
      Register_Routine
        (T,
         Test_Service_Get_By_Id'Access,
         "Get service by id returns correct fields");
      Register_Routine
        (T,
         Test_Service_Get_By_Id_Not_Found'Access,
         "Get service by unknown id raises Not_Found");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Repository_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Service.Repository_Tests;
