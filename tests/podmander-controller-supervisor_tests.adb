--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Behavioral tests for Podmander.Controller.Supervisor.
--  Uses in-process :memory: DB and a real ROUTER socket wrapped in a Control
--  Channel. With no connected peer the ROUTER silently drops outbound messages
--  (mandatory routing is off), so Tick's encode+send+Set_State path can be
--  exercised without a live agent.

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Agent.Repository;
with Podmander.Control_Channel;
with Podmander.Controller.Node.Repository;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Controller.Supervisor;
with Podmander.Database;
with Podmander.Types;

package body Podmander.Controller.Supervisor_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Types;

   package DB renames Podmander.Database;
   package Agent_Repo renames Podmander.Controller.Agent.Repository;
   package Node_Repo renames Podmander.Controller.Node.Repository;
   package Svc_Repo renames Podmander.Controller.Service.Repository;
   package Cat_Repo renames Podmander.Controller.Service_Catalog.Repository;
   package Supervisor renames Podmander.Controller.Supervisor;

   type Supervisor_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Supervisor_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Supervisor"));

   overriding
   procedure Register_Tests (T : in out Supervisor_Test);

   --  Seed a service with version 1 and return its service id.
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

   --  Seed a node and return its node id.
   function Seed_Node
     (Handle : in out DB.DB_Handle; Name : String) return Node_Id_Type
   is (Node_Repo.Create_Or_Get (Handle, Name));

   --  Seed a Registered agent linked to the given node, with the given
   --  connection identity.
   procedure Seed_Agent
     (Handle        : in out DB.DB_Handle;
      Name          : String;
      Node_Id       : Node_Id_Type;
      Connection_Id : String)
   is
      Info : constant Agent_Info :=
        (Id            => 0,
         Name          => To_Unbounded_String (Name),
         Connection_Id => To_Unbounded_String (Connection_Id),
         State         => Registered,
         Last_Seen     => Clock,
         Node_Id       => Node_Id);
   begin
      Agent_Repo.Register (Handle, Info);
   end Seed_Agent;

   -----------------------------------------------
   --  Test 1: Recover resets In_Progress -> Pending
   -----------------------------------------------

   procedure Test_Recover_Resets_In_Progress
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D   : DB.DB_Handle := DB.Open (":memory:");
      Svc : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "app");
      Cat : Podmander.Controller.Service_Catalog_Entry :=
        Cat_Repo.Create_Entry
          (DB => D, Service_Id => Svc, Target_Version => 1);
      Ok  : Boolean;
      pragma Unreferenced (Ok);
   begin
      --  Force entry to In_Progress as if a previous controller crashed.
      Ok := Cat_Repo.Set_State (D, Cat.Id, Podmander.Controller.In_Progress);

      Supervisor.Recover (D);

      Cat := Cat_Repo.Get_By_Id (D, Cat.Id);
      Assert
        (Cat.State = Podmander.Controller.Pending,
         "Recover must reset In_Progress entries to Pending");
   end Test_Recover_Resets_In_Progress;

   -----------------------------------------------
   --  Test 2: Recover leaves Deployed entry untouched
   -----------------------------------------------

   procedure Test_Recover_Leaves_Deployed_Untouched
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D   : DB.DB_Handle := DB.Open (":memory:");
      Svc : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "svc");
      Cat : Podmander.Controller.Service_Catalog_Entry :=
        Cat_Repo.Create_Entry
          (DB => D, Service_Id => Svc, Target_Version => 1);
      Ok  : Boolean;
      pragma Unreferenced (Ok);
   begin
      Ok := Cat_Repo.Update_On_Success (D, Cat.Id, 1);

      Supervisor.Recover (D);

      Cat := Cat_Repo.Get_By_Id (D, Cat.Id);
      Assert
        (Cat.State = Podmander.Controller.Deployed,
         "Recover must not touch Deployed entries");
   end Test_Recover_Leaves_Deployed_Untouched;

   -----------------------------------------------
   --  Test 3: Tick schedules and deploys an unscheduled entry end-to-end
   -----------------------------------------------

   procedure Test_Tick_Schedules_Unscheduled_Entry
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      Svc  : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "svc");
      Node : constant Node_Id_Type := Seed_Node (D, "node-1");
      Cat  : Podmander.Controller.Service_Catalog_Entry :=
        Cat_Repo.Create_Entry
          (DB             => D,
           Service_Id     => Svc,
           Node_Id        => (Present => False),
           Target_Version => 1);
      Chan : Podmander.Control_Channel.Channel;
   begin
      --  First_Available selects a node only when a Registered agent exists.
      --  Seed one so the scheduling step can assign a node.
      Seed_Agent (D, "agent-1", Node, "conn-abc");

      Supervisor.Tick (D, Chan);

      Cat := Cat_Repo.Get_By_Id (D, Cat.Id);
      Assert
        (Cat.Assigned_Node.Present,
         "Tick must assign a node to an unscheduled entry when a Registered agent exists");
      Assert
        (Cat.State = Podmander.Controller.In_Progress,
         "Tick must deploy the entry once a node is assigned and an agent is Registered");

   end Test_Tick_Schedules_Unscheduled_Entry;

   -----------------------------------------------
   --  Test 4: Tick dispatches pending deploy, entry becomes In_Progress
   -----------------------------------------------

   procedure Test_Tick_Deploys_Pending_Entry
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      Svc  : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "svc");
      Node : constant Node_Id_Type := Seed_Node (D, "node-1");
      Cat  : Podmander.Controller.Service_Catalog_Entry :=
        Cat_Repo.Create_Entry
          (DB             => D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 1);
      Chan : Podmander.Control_Channel.Channel;
   begin
      --  Register a Registered agent on this node.
      Seed_Agent (D, "agent-1", Node, "conn-abc");

      Supervisor.Tick (D, Chan);

      Cat := Cat_Repo.Get_By_Id (D, Cat.Id);
      Assert
        (Cat.State = Podmander.Controller.In_Progress,
         "Tick must transition a Pending entry with a Registered agent to In_Progress");

   end Test_Tick_Deploys_Pending_Entry;

   -----------------------------------------------
   --  Test 5: Tick leaves Pending when node has no registered agent
   -----------------------------------------------

   procedure Test_Tick_No_Agent_Leaves_Pending
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      Svc  : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "svc");
      Node : constant Node_Id_Type := Seed_Node (D, "node-1");
      Cat  : Podmander.Controller.Service_Catalog_Entry :=
        Cat_Repo.Create_Entry
          (DB             => D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 1);
      Chan : Podmander.Control_Channel.Channel;
   begin
      --  No agent seeded: node exists but has no Registered agent.
      Supervisor.Tick (D, Chan);

      Cat := Cat_Repo.Get_By_Id (D, Cat.Id);
      Assert
        (Cat.State = Podmander.Controller.Pending,
         "Tick must leave entry Pending when no registered agent serves its node");

   end Test_Tick_No_Agent_Leaves_Pending;

   -----------------------------------------------
   --  Test 6: Tick on empty catalog is a no-op and does not crash
   -----------------------------------------------

   procedure Test_Tick_Empty_Catalog_Is_Noop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      Chan : Podmander.Control_Channel.Channel;
   begin
      Supervisor.Tick (D, Chan);
   --  No assert needed; reaching this point without an exception is the test.
   end Test_Tick_Empty_Catalog_Is_Noop;

   overriding
   procedure Register_Tests (T : in out Supervisor_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Recover_Resets_In_Progress'Access,
         "Recover resets In_Progress entries to Pending");
      Register_Routine
        (T,
         Test_Recover_Leaves_Deployed_Untouched'Access,
         "Recover leaves Deployed entries untouched");
      Register_Routine
        (T,
         Test_Tick_Schedules_Unscheduled_Entry'Access,
         "Tick schedules and deploys an unscheduled entry when a Registered agent exists");
      Register_Routine
        (T,
         Test_Tick_Deploys_Pending_Entry'Access,
         "Tick transitions Pending entry to In_Progress when agent is registered");
      Register_Routine
        (T,
         Test_Tick_No_Agent_Leaves_Pending'Access,
         "Tick leaves entry Pending when no registered agent serves its node");
      Register_Routine
        (T,
         Test_Tick_Empty_Catalog_Is_Noop'Access,
         "Tick on empty catalog is a no-op");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Supervisor_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Supervisor_Tests;
