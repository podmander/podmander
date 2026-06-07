--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Scheduler;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Strategies.First_Available;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Database;
with Podmander.Types;

package body Podmander.Controller.Scheduler_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Database;
   package Svc_Repo renames Podmander.Controller.Service.Repository;
   package Cat_Repo renames Podmander.Controller.Service_Catalog.Repository;
   package Agent_Repo renames Podmander.Controller.Agent.Repository;
   package Scheduler renames Podmander.Controller.Scheduler;

   use type DB.Error_Kind;
   use type Scheduler.Schedule_Error;

   type Scheduler_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Scheduler_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Scheduler"));

   overriding
   procedure Register_Tests (T : in out Scheduler_Test);

   -- Helper: create a service and at least one version so FK constraints
   -- are satisfied. Returns the service id.
   function Seed_Service (Handle : in out DB.DB_Handle; Name : String; Versions : Positive) return Podmander.Controller.Service_Id_Type is
      Svc_Rec : constant Podmander.Controller.Service.Service := Svc_Repo.Create (Handle, Name);
      SV      : Podmander.Controller.Service_Version;
   begin
      for V in 1 .. Versions loop
         SV.Id := 0;
         SV.Service_Id := Svc_Rec.Id;
         SV.Version := Podmander.Controller.Service_Version_Type (V);
         SV.Image := To_Unbounded_String ("test:latest");
         SV.Created_At := Ada.Calendar.Clock;
         Svc_Repo.Create_Version (Handle, SV);
      end loop;
      return Svc_Rec.Id;
   end Seed_Service;

   -- Helper: register a single agent in Registered state.
   procedure Register_Agent (Handle : in out DB.DB_Handle; Name : String; Node_Id : String) is
      Info : constant Podmander.Types.Agent_Info :=
        (Id        => 0,
         Name      => To_Unbounded_String (Name),
         Node_Id   => To_Unbounded_String (Node_Id),
         State     => Podmander.Types.Registered,
         Last_Seen => Ada.Calendar.Clock);
   begin
      Agent_Repo.Register (Handle, Info);
   end Register_Agent;

   -- Helper: register an agent and return its auto-generated id.
   function Seed_Agent (Handle : in out DB.DB_Handle; Name : String; Node_Id : String) return Podmander.Controller.Agent_Id_Type is
      use Podmander.Types;
   begin
      Register_Agent (Handle, Name, Node_Id);
      return Podmander.Controller.Agent_Id_Type
        (Agent_Repo.Load_All (Handle).Element (Name).Id);
   end Seed_Agent;

   --------------------------
   -- Test_Schedule_New_Entry
   --------------------------

   procedure Test_Schedule_New_Entry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Svc    : Podmander.Controller.Service_Id_Type := Seed_Service (D, "web", 2);
      Result : Scheduler.Schedule_Result;
   begin
      --  Register one agent so the Scheduler can assign it
      Register_Agent (D, "agent-1", "node-1");

      Result := Scheduler.Schedule (D, Service_Id => Svc, Target_Version => 2,
                                    Strategy => Podmander.Controller.Strategies.First_Available.Instance);
      Assert (Result.Ok, "Schedule should succeed for new entry");
      Assert (Result.Catalog_Entry.Id > 0, "Id should be positive after create");
      Assert (Result.Catalog_Entry.Service_Id = Svc, "Service_Id should match");
      Assert (Result.Catalog_Entry.Agent_Id > 0, "Agent_Id should be assigned");
      Assert (Result.Catalog_Entry.Current_Version = 0, "Current_Version should be 0");
      Assert (Result.Catalog_Entry.Target_Version = Podmander.Controller.Service_Version_Type (2), "Target_Version should be 2");
      Assert (Result.Catalog_Entry.State = Podmander.Controller.Pending, "State should be Pending");
      Assert (Result.Error = Scheduler.None, "Error should be None");
   end Test_Schedule_New_Entry;

   ---------------------------------
   -- Test_Schedule_New_Entry_No_Agent
   ---------------------------------

   procedure Test_Schedule_New_Entry_No_Agent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Svc    : Podmander.Controller.Service_Id_Type := Seed_Service (D, "db", 1);
      Result : Scheduler.Schedule_Result;
   begin
      --  No agents registered — Scheduler should create entry with empty Node_Id
      Result := Scheduler.Schedule (D, Service_Id => Svc, Target_Version => 1,
                                    Strategy => Podmander.Controller.Strategies.First_Available.Instance);
      Assert (Result.Ok, "Schedule should succeed with no agent");
      Assert (Result.Catalog_Entry.Agent_Id = 0, "Agent_Id should be 0 when no agent is connected");
      Assert (Result.Error = Scheduler.None, "Error should be None");
   end Test_Schedule_New_Entry_No_Agent;

   --------------------------------
   -- Test_Schedule_Update_Existing
   --------------------------------

   procedure Test_Schedule_Update_Existing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : Podmander.Controller.Service_Id_Type := Seed_Service (D, "web", 3);
      Agent   : constant Podmander.Controller.Agent_Id_Type :=
         Seed_Agent (D, "agent-1", "node-1");
      Created : Podmander.Controller.Service_Catalog_Entry :=
        Cat_Repo.Create_Entry (D, Service_Id => Svc, Agent_Id => Agent, Target_Version => 1);
      Result  : Scheduler.Schedule_Result;
   begin
      --  Mark as failed first to verify it gets cleared
      declare
         Ignored : Boolean := Cat_Repo.Update_On_Failure (D, Created.Id);
         pragma Unreferenced (Ignored);
      begin
         null;
      end;

      --  Schedule with a new target_version
      Result := Scheduler.Schedule (D, Service_Id => Svc, Target_Version => 3,
                                    Strategy => Podmander.Controller.Strategies.First_Available.Instance);

      Assert (Result.Ok, "Schedule should succeed for existing entry");
      Assert (Result.Catalog_Entry.Id = Created.Id, "Entry id should remain the same");
      Assert (Result.Catalog_Entry.Target_Version = Podmander.Controller.Service_Version_Type (3), "Target_Version should be updated to 3");
      Assert (Result.Catalog_Entry.Current_Version = 0, "Current_Version should remain 0");
      Assert (Result.Catalog_Entry.State = Podmander.Controller.Pending, "State should be Pending after schedule");
      Assert (Result.Error = Scheduler.None, "Error should be None");
   end Test_Schedule_Update_Existing;

   ------------------------------------
   -- Test_Schedule_Update_Assign_Node
   ------------------------------------

   procedure Test_Schedule_Update_Assign_Node (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : Podmander.Controller.Service_Id_Type := Seed_Service (D, "web", 2);
      Created : Podmander.Controller.Service_Catalog_Entry :=
        Cat_Repo.Create_Entry (D, Service_Id => Svc, Target_Version => 1);
      Result  : Scheduler.Schedule_Result;
   begin
      --  Register one agent so the Scheduler can assign it
      Register_Agent (D, "agent-1", "assigned-node");

      --  Schedule — the Scheduler should assign the registered agent's node
      Result := Scheduler.Schedule (D, Service_Id => Svc, Target_Version => 2,
                                    Strategy => Podmander.Controller.Strategies.First_Available.Instance);

      Assert (Result.Ok, "Schedule should succeed");
      Assert (Result.Catalog_Entry.Id = Created.Id, "Entry id should remain the same");
      Assert
        (Result.Catalog_Entry.Agent_Id > 0, "Agent_Id should be assigned after assign");
      Assert (Result.Catalog_Entry.Target_Version = Podmander.Controller.Service_Version_Type (2), "Target_Version should be updated");
      Assert (Result.Error = Scheduler.None, "Error should be None");
   end Test_Schedule_Update_Assign_Node;

   ------------------------------------
   -- Test_Schedule_Picks_First_Agent
   ------------------------------------

   procedure Test_Schedule_Picks_First_Agent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Svc    : Podmander.Controller.Service_Id_Type := Seed_Service (D, "cache", 1);
      Result : Scheduler.Schedule_Result;
   begin
      --  Register two agents — Scheduler should pick the first one and succeed
      Register_Agent (D, "agent-1", "node-1");
      Register_Agent (D, "agent-2", "node-2");

      Result := Scheduler.Schedule (D, Service_Id => Svc, Target_Version => 1,
                                    Strategy => Podmander.Controller.Strategies.First_Available.Instance);
      Assert (Result.Ok, "Schedule should succeed with multiple agents");
      Assert (Result.Catalog_Entry.Agent_Id /= 0, "Agent_Id should be assigned");
      Assert (Result.Error = Scheduler.None, "Error should be None");
   end Test_Schedule_Picks_First_Agent;

   overriding
   procedure Register_Tests (T : in out Scheduler_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Schedule_New_Entry'Access, "Schedule creates a new catalog entry");
      Register_Routine
        (T, Test_Schedule_New_Entry_No_Agent'Access, "Schedule creates entry with empty Node_Id when no agent");
      Register_Routine
        (T, Test_Schedule_Update_Existing'Access, "Schedule updates target and sets state = Pending on existing");
      Register_Routine
        (T, Test_Schedule_Update_Assign_Node'Access, "Schedule assigns node when updating existing entry");
      Register_Routine
        (T, Test_Schedule_Picks_First_Agent'Access, "Schedule picks first agent when multiple are connected");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Scheduler_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Scheduler_Tests;