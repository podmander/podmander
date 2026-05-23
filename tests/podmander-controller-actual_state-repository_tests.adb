--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;
with Podmander.Controller;
with Podmander.Controller.Actual_State.Repository;
with Podmander.Controller.Service.Repository;
with Podmander.Database;

package body Podmander.Controller.Actual_State.Repository_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Database;
   package Svc renames Podmander.Controller.Service.Repository;
   package Repo renames Podmander.Controller.Actual_State.Repository;

   use type DB.Error_Kind;

   type Repository_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Repository_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Actual_State.Repository"));

   overriding
   procedure Register_Tests (T : in out Repository_Test);

   My_Service : constant String := "web-app";
   My_Node    : constant String := "node-001";
   My_Node2   : constant String := "node-002";

    --  Create a minimal service version for testing
    procedure Seed_Service_Version
      (Handle : in out DB.DB_Handle; Service : String; Version : Positive)
    is
       Svc_Rec : constant Podmander.Controller.Service.Service :=
         Svc.Create (Handle, Service);
       SV      : Podmander.Controller.Service_Version;
    begin
       SV.Id := 0;
       SV.Service_Id := Svc_Rec.Id;
       SV.Version := Version;
       SV.Image := To_Unbounded_String ("test:latest");
       SV.Created_At := Ada.Calendar.Clock;
       Svc.Create_Version (Handle, SV);
    end Seed_Service_Version;

   function Make_Entry
     (Service : String; Node : String; Version : Positive)
      return Podmander.Controller.Actual_State_Entry is
   begin
      return
        (Service_Name => To_Unbounded_String (Service),
         Node_Id      => To_Unbounded_String (Node),
         Version      => Version,
         Updated_At   => Ada.Calendar.Clock);
   end Make_Entry;

   --  Format time as ISO 8601 for string comparison
   function Format_Time (T : Ada.Calendar.Time) return String is
      Raw : constant String := Ada.Calendar.Formatting.Image (T);
   begin
      return Raw (1 .. 10) & "T" & Raw (12 .. 19) & "Z";
   end Format_Time;

   procedure Test_Upsert_Inserts (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D     : DB.DB_Handle := DB.Open (":memory:");
      E     : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node, 1);
      All_E : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      Seed_Service_Version (D, My_Service, 1);
      Repo.Upsert (D, E);
      All_E := Repo.Get_All (D);
      Assert
        (Natural (All_E.Length) = 1, "Should have one entry after upsert");
   end Test_Upsert_Inserts;

   procedure Test_Upsert_Updates (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D     : DB.DB_Handle := DB.Open (":memory:");
      E1    : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node, 1);
      E2    : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node, 2);
      All_E : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      Seed_Service_Version (D, My_Service, 1);
      Seed_Service_Version (D, My_Service, 2);
      Repo.Upsert (D, E1);
      Repo.Upsert (D, E2);
      All_E := Repo.Get_All (D);
      Assert
        (Natural (All_E.Length) = 1,
         "Should have one entry after upsert of same key");
      Assert
        (All_E.First_Element.Version = 2, "Version should be updated to 2");
   end Test_Upsert_Updates;

   procedure Test_Get_All_Returns_All
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D     : DB.DB_Handle := DB.Open (":memory:");
      E1    : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node, 1);
      E2    : Podmander.Controller.Actual_State_Entry :=
        Make_Entry ("db", "node-001", 1);
      E3    : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node2, 1);
      All_E : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      Seed_Service_Version (D, My_Service, 1);
      Seed_Service_Version (D, "db", 1);
      Repo.Upsert (D, E1);
      Repo.Upsert (D, E2);
      Repo.Upsert (D, E3);
      All_E := Repo.Get_All (D);
      Assert
        (Natural (All_E.Length) = 3, "Should have 3 entries after 3 upserts");
   end Test_Get_All_Returns_All;

   procedure Test_Get_For_Service (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D           : DB.DB_Handle := DB.Open (":memory:");
      E1          : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node, 1);
      E2          : Podmander.Controller.Actual_State_Entry :=
        Make_Entry ("db", "node-001", 1);
      E3          : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node2, 2);
      Svc_Entries : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      Seed_Service_Version (D, My_Service, 1);
      Seed_Service_Version (D, My_Service, 2);
      Seed_Service_Version (D, "db", 1);
      Repo.Upsert (D, E1);
      Repo.Upsert (D, E2);
      Repo.Upsert (D, E3);
      Svc_Entries := Repo.Get_For_Service (D, My_Service);
      Assert
        (Natural (Svc_Entries.Length) = 2,
         "Should have 2 entries for service " & My_Service);
   end Test_Get_For_Service;

   procedure Test_Get_For_Service_Unknown
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D           : DB.DB_Handle := DB.Open (":memory:");
      E1          : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node, 1);
      Svc_Entries : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      Seed_Service_Version (D, My_Service, 1);
      Repo.Upsert (D, E1);
      Svc_Entries := Repo.Get_For_Service (D, "nonexistent");
      Assert
        (Natural (Svc_Entries.Length) = 0,
         "Should have 0 entries for unknown service");
   end Test_Get_For_Service_Unknown;

   procedure Test_Remove (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D     : DB.DB_Handle := DB.Open (":memory:");
      E1    : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node, 1);
      E2    : Podmander.Controller.Actual_State_Entry :=
        Make_Entry ("db", "node-001", 1);
      All_E : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      Seed_Service_Version (D, My_Service, 1);
      Seed_Service_Version (D, "db", 1);
      Repo.Upsert (D, E1);
      Repo.Upsert (D, E2);
      Repo.Remove (D, My_Service, My_Node);
      All_E := Repo.Get_All (D);
      Assert (Natural (All_E.Length) = 1, "Should have 1 entry after remove");
      Assert
        (To_String (All_E.First_Element.Service_Name) = "db",
         "Remaining entry should be 'db'");
   end Test_Remove;

   procedure Test_Remove_Unknown_Noop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D     : DB.DB_Handle := DB.Open (":memory:");
      E1    : Podmander.Controller.Actual_State_Entry :=
        Make_Entry (My_Service, My_Node, 1);
      All_E : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      Seed_Service_Version (D, My_Service, 1);
      Repo.Upsert (D, E1);
      Repo.Remove (D, "nonexistent", My_Node);
      All_E := Repo.Get_All (D);
      Assert
        (Natural (All_E.Length) = 1,
         "Entry should still exist after removing unknown key");
   end Test_Remove_Unknown_Noop;

   overriding
   procedure Register_Tests (T : in out Repository_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Upsert_Inserts'Access,
         "Upsert inserts a new actual_state entry");
      Register_Routine
        (T,
         Test_Upsert_Updates'Access,
         "Upsert updates an existing actual_state entry");
      Register_Routine
        (T,
         Test_Get_All_Returns_All'Access,
         "Get_All returns all actual_state entries");
      Register_Routine
        (T,
         Test_Get_For_Service'Access,
         "Get_For_Service returns entries for a specific service");
      Register_Routine
        (T,
         Test_Get_For_Service_Unknown'Access,
         "Get_For_Service returns empty vector for unknown service");
      Register_Routine
        (T, Test_Remove'Access, "Remove deletes an actual_state entry");
      Register_Routine
        (T,
         Test_Remove_Unknown_Noop'Access,
         "Remove on unknown key is a no-op");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Repository_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Actual_State.Repository_Tests;
