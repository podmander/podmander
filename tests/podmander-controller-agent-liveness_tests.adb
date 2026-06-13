--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Behavioral tests for Podmander.Controller.Agent.Liveness.
--  Uses an in-process :memory: DB. Agents are seeded with explicit State and
--  Last_Seen values so that Check_Timeouts and Recover can be exercised
--  without a running poll loop. Agent_Timeout => 30.0 means the unresponsive
--  threshold is 60 s and the lost threshold is 90 s; seed offsets are
--  multiples of the timeout (2.5x => 75 s, 3.5x => 105 s), leaving a 15 s
--  clearance to each boundary that dwarfs any seeding I/O latency, so the
--  wall-clock comparison in Check_Timeouts cannot jitter across a threshold.

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Agent.Liveness;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Node.Repository;
with Podmander.Database;
with Podmander.Types;

package body Podmander.Controller.Agent.Liveness_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Types;

   package DB renames Podmander.Database;
   package Agent_Repo renames Podmander.Controller.Agent.Repository;
   package Node_Repo renames Podmander.Controller.Node.Repository;
   package Liveness renames Podmander.Controller.Agent.Liveness;

   type Liveness_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Liveness_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Agent.Liveness"));

   overriding
   procedure Register_Tests (T : in out Liveness_Test);

   --  Seed an agent with an explicit state and last-seen timestamp.
   --  A dedicated node is created for each agent to satisfy the FK constraint
   --  (agents.node_id references nodes.id); the node itself is irrelevant to
   --  liveness logic and is never queried by the tests.
   procedure Seed_Agent
     (Handle    : in out DB.DB_Handle;
      Name      : String;
      State     : Agent_State;
      Last_Seen : Ada.Calendar.Time)
   is
      Node_Id : constant Podmander.Types.Node_Id_Type :=
        Node_Repo.Create_Or_Get (Handle, "node-" & Name);
      Info : Agent_Info :=
        (Id            => 0,
         Name          => To_Unbounded_String (Name),
         Connection_Id => To_Unbounded_String ("conn-" & Name),
         State         => Registered,
         Last_Seen     => Last_Seen,
         Node_Id       => Node_Id);
   begin
      Agent_Repo.Register (Handle, Info);
      --  Register always persists as Registered; patch the state afterwards.
      if State /= Registered then
         Info.State := State;
         Agent_Repo.Set_State (Handle, Info);
      end if;
   end Seed_Agent;

   --  Return the state of the sole agent named Name from the DB.
   function Get_State
     (Handle : in out DB.DB_Handle; Name : String) return Agent_State
   is
      All_Agents : constant Agent_Maps.Map := Agent_Repo.Load_All (Handle);
   begin
      return All_Agents.Element (Name).State;
   end Get_State;

   Agent_Timeout : constant Duration := 30.0;

   --  Idle offsets for seeding, expressed as multiples of the timeout so the
   --  clearance to each state boundary scales with it. At Agent_Timeout = 30.0
   --  these are 75 s and 105 s, each 15 s clear of the 60 s/90 s thresholds --
   --  far larger than any seeding latency, so the comparison never jitters.
   Idle_Unresponsive : constant Duration := 2.5 * Agent_Timeout;
   Idle_Lost         : constant Duration := 3.5 * Agent_Timeout;

   -----------------------------------------------
   --  Check_Timeouts tests
   -----------------------------------------------

   --  Test 1: Registered agent idle 2.5x timeout -> Unresponsive
   procedure Test_Registered_Idle_2_5x_Becomes_Unresponsive
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "a1", Registered, Clock - Idle_Unresponsive);
      Liveness.Check_Timeouts (D, Agent_Timeout);
      Assert
        (Get_State (D, "a1") = Unresponsive,
         "Registered agent idle 2.5x timeout must become Unresponsive");
   end Test_Registered_Idle_2_5x_Becomes_Unresponsive;

   --  Test 2: Registered agent idle 3.5x timeout -> Lost
   procedure Test_Registered_Idle_3_5x_Becomes_Lost
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "a2", Registered, Clock - Idle_Lost);
      Liveness.Check_Timeouts (D, Agent_Timeout);
      Assert
        (Get_State (D, "a2") = Lost,
         "Registered agent idle 3.5x timeout must become Lost");
   end Test_Registered_Idle_3_5x_Becomes_Lost;

   --  Test 3: Unresponsive agent idle 3.5x timeout -> Lost
   procedure Test_Unresponsive_Idle_3_5x_Becomes_Lost
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "a3", Unresponsive, Clock - Idle_Lost);
      Liveness.Check_Timeouts (D, Agent_Timeout);
      Assert
        (Get_State (D, "a3") = Lost,
         "Unresponsive agent idle 3.5x timeout must become Lost");
   end Test_Unresponsive_Idle_3_5x_Becomes_Lost;

   --  Test 4: Unresponsive agent idle 2.5x timeout stays Unresponsive
   procedure Test_Unresponsive_Idle_2_5x_Stays_Unresponsive
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "a4", Unresponsive, Clock - Idle_Unresponsive);
      Liveness.Check_Timeouts (D, Agent_Timeout);
      Assert
        (Get_State (D, "a4") = Unresponsive,
         "Unresponsive agent idle 2.5x timeout must stay Unresponsive");
   end Test_Unresponsive_Idle_2_5x_Stays_Unresponsive;

   --  Test 5: Registered agent fresh (offset 0) stays Registered
   procedure Test_Registered_Fresh_Stays_Registered
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "a5", Registered, Clock);
      Liveness.Check_Timeouts (D, Agent_Timeout);
      Assert
        (Get_State (D, "a5") = Registered,
         "Fresh Registered agent must stay Registered");
   end Test_Registered_Fresh_Stays_Registered;

   --  Test 6: Already Lost agent stays Lost regardless of elapsed time
   procedure Test_Lost_Stays_Lost
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "a6", Lost, Clock - Idle_Lost);
      Liveness.Check_Timeouts (D, Agent_Timeout);
      Assert
        (Get_State (D, "a6") = Lost,
         "Already Lost agent must stay Lost");
   end Test_Lost_Stays_Lost;

   --  Test 7: Empty agent set is a no-op
   procedure Test_Check_Timeouts_Empty_Is_Noop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Liveness.Check_Timeouts (D, Agent_Timeout);
      --  Reaching here without exception is the test.
   end Test_Check_Timeouts_Empty_Is_Noop;

   -----------------------------------------------
   --  Recover tests
   -----------------------------------------------

   --  Test 8: Registered agent becomes Unresponsive after Recover
   procedure Test_Recover_Registered_Becomes_Unresponsive
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "b1", Registered, Clock);
      Liveness.Recover (D);
      Assert
        (Get_State (D, "b1") = Unresponsive,
         "Recover must set Registered agents to Unresponsive");
   end Test_Recover_Registered_Becomes_Unresponsive;

   --  Test 9: Unresponsive agent stays Unresponsive after Recover
   procedure Test_Recover_Unresponsive_Stays_Unresponsive
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "b2", Unresponsive, Clock);
      Liveness.Recover (D);
      Assert
        (Get_State (D, "b2") = Unresponsive,
         "Recover must leave Unresponsive agents Unresponsive");
   end Test_Recover_Unresponsive_Stays_Unresponsive;

   --  Test 10: Lost agent stays Lost after Recover
   procedure Test_Recover_Lost_Stays_Lost
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Seed_Agent (D, "b3", Lost, Clock);
      Liveness.Recover (D);
      Assert
        (Get_State (D, "b3") = Lost,
         "Recover must not change Lost agents");
   end Test_Recover_Lost_Stays_Lost;

   --  Test 11: Empty agent set is a no-op
   procedure Test_Recover_Empty_Is_Noop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
   begin
      Liveness.Recover (D);
      --  Reaching here without exception is the test.
   end Test_Recover_Empty_Is_Noop;

   overriding
   procedure Register_Tests (T : in out Liveness_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Registered_Idle_2_5x_Becomes_Unresponsive'Access,
         "Registered agent idle 2.5x timeout becomes Unresponsive");
      Register_Routine
        (T,
         Test_Registered_Idle_3_5x_Becomes_Lost'Access,
         "Registered agent idle 3.5x timeout becomes Lost");
      Register_Routine
        (T,
         Test_Unresponsive_Idle_3_5x_Becomes_Lost'Access,
         "Unresponsive agent idle 3.5x timeout becomes Lost");
      Register_Routine
        (T,
         Test_Unresponsive_Idle_2_5x_Stays_Unresponsive'Access,
         "Unresponsive agent idle 2.5x timeout stays Unresponsive");
      Register_Routine
        (T,
         Test_Registered_Fresh_Stays_Registered'Access,
         "Fresh Registered agent stays Registered");
      Register_Routine
        (T,
         Test_Lost_Stays_Lost'Access,
         "Lost agent stays Lost regardless of elapsed time");
      Register_Routine
        (T,
         Test_Check_Timeouts_Empty_Is_Noop'Access,
         "Check_Timeouts on empty agent set is a no-op");
      Register_Routine
        (T,
         Test_Recover_Registered_Becomes_Unresponsive'Access,
         "Recover sets Registered agents to Unresponsive");
      Register_Routine
        (T,
         Test_Recover_Unresponsive_Stays_Unresponsive'Access,
         "Recover leaves Unresponsive agents Unresponsive");
      Register_Routine
        (T,
         Test_Recover_Lost_Stays_Lost'Access,
         "Recover does not change Lost agents");
      Register_Routine
        (T,
         Test_Recover_Empty_Is_Noop'Access,
         "Recover on empty agent set is a no-op");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Liveness_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Agent.Liveness_Tests;
