--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  DI-seam tests for the Scheduler's Strategy parameter. Each test injects
--  a test-only Strategy_Type implementation to verify that Schedule persists
--  exactly the node the strategy chose (or leaves the entry unscheduled when
--  the strategy returns no node).

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Node.Repository;
with Podmander.Controller.Scheduler;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Strategies;
with Podmander.Database;
with Podmander.Types;

package body Podmander.Controller.Scheduler_Seam_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Types;

   package DB renames Podmander.Database;
   package Svc_Repo renames Podmander.Controller.Service.Repository;
   package Node_Repo renames Podmander.Controller.Node.Repository;
   package Scheduler renames Podmander.Controller.Scheduler;
   use Podmander.Controller.Strategies;

   use type Scheduler.Schedule_Error;

   --  Test-only strategy: always returns the fixed node id it was initialised
   --  with. Does not touch DB.
   type Fixed_Node_Strategy is new Strategy_Type with record
      Fixed_Id : Node_Id_Type;
   end record;

   overriding
   function Select_Node
     (Strategy       : Fixed_Node_Strategy;
      DB             : in out Podmander.Database.DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Podmander.Controller.Node_Option
   is
      pragma Unreferenced (DB, Service_Id, Target_Version);
   begin
      return (Present => True, Node_Id => Strategy.Fixed_Id);
   end Select_Node;

   --  Test-only strategy: always reports no eligible node.
   type No_Node_Strategy is new Strategy_Type with null record;

   overriding
   function Select_Node
     (Strategy       : No_Node_Strategy;
      DB             : in out Podmander.Database.DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Podmander.Controller.Node_Option
   is
      pragma Unreferenced (Strategy, DB, Service_Id, Target_Version);
   begin
      return (Present => False);
   end Select_Node;

   type Seam_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Seam_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Scheduler (strategy seam)"));

   overriding
   procedure Register_Tests (T : in out Seam_Test);

   function Seed_Service
     (Handle : in out DB.DB_Handle; Name : String)
      return Podmander.Controller.Service_Id_Type
   is
      Svc_Rec : constant Podmander.Controller.Service.Service :=
        Svc_Repo.Create (Handle, Name);
      SV      : Podmander.Controller.Service_Version;
   begin
      SV.Id := 0;
      SV.Service_Id := Svc_Rec.Id;
      SV.Version := 1;
      SV.Image := To_Unbounded_String ("test:latest");
      SV.Created_At := Clock;
      Svc_Repo.Create_Version (Handle, SV);
      return Svc_Rec.Id;
   end Seed_Service;

   function Seed_Node
     (Handle : in out DB.DB_Handle; Name : String) return Node_Id_Type is
   begin
      return Node_Repo.Create_Or_Get (Handle, Name);
   end Seed_Node;

   -----------------------------------------------
   -- Test_Schedule_Persists_Strategy_Node
   -----------------------------------------------

   procedure Test_Schedule_Persists_Strategy_Node
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D        : DB.DB_Handle := DB.Open (":memory:");
      Svc      : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "app");
      Node     : constant Node_Id_Type := Seed_Node (D, "node-1");
      Strategy : constant Fixed_Node_Strategy :=
        Fixed_Node_Strategy'(Fixed_Id => Node);
      Result   : Scheduler.Schedule_Result;
   begin
      Result :=
        Scheduler.Schedule
          (DB             => D,
           Service_Id     => Svc,
           Target_Version => 1,
           Strategy       => Strategy);
      Assert (Result.Ok, "Schedule should succeed");
      Assert (Result.Error = Scheduler.None, "Error should be None");
      Assert
        (Result.Catalog_Entry.Node_Id.Present
         and then Result.Catalog_Entry.Node_Id.Node_Id = Node,
         "Scheduler should persist the node chosen by the injected strategy");
   end Test_Schedule_Persists_Strategy_Node;

   -----------------------------------------------
   -- Test_Schedule_Unscheduled_On_No_Node
   -----------------------------------------------

   procedure Test_Schedule_Unscheduled_On_No_Node
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D        : DB.DB_Handle := DB.Open (":memory:");
      Svc      : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "app");
      Strategy : No_Node_Strategy;
      Result   : Scheduler.Schedule_Result;
   begin
      Result :=
        Scheduler.Schedule
          (DB             => D,
           Service_Id     => Svc,
           Target_Version => 1,
           Strategy       => Strategy);
      Assert
        (Result.Ok,
         "Schedule should succeed even when strategy returns no node");
      Assert (Result.Error = Scheduler.None, "Error should be None");
      Assert
        (not Result.Catalog_Entry.Node_Id.Present,
         "Catalog entry should be unscheduled when strategy returns no node");
   end Test_Schedule_Unscheduled_On_No_Node;

   overriding
   procedure Register_Tests (T : in out Seam_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Schedule_Persists_Strategy_Node'Access,
         "Scheduler persists node chosen by injected strategy");
      Register_Routine
        (T,
         Test_Schedule_Unscheduled_On_No_Node'Access,
         "Scheduler leaves entry unscheduled when strategy returns no node");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Seam_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Scheduler_Seam_Tests;
