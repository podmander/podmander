--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;
with Podmander.Controller.Agent.Repository;
with Podmander.Database;
with Podmander.Types;

package body Podmander.Controller.Agent.Repository_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB   renames Podmander.Database;
   package Repo renames Podmander.Controller.Agent.Repository;

   use type DB.Error_Kind;

   type Repository_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name
     (T : Repository_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Agent.Repository"));

   overriding procedure Register_Tests (T : in out Repository_Test);

   --  Format time as ISO 8601 for string comparison
   function Format_Time (T : Ada.Calendar.Time) return String is
      Raw : constant String := Ada.Calendar.Formatting.Image (T);
   begin
      return Raw (1 .. 10) & "T" & Raw (12 .. 19) & "Z";
   end Format_Time;

   ---------
   --  Register + Load_All
   ---------

   procedure Test_Register_And_Load_All
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D     : DB.DB_Handle := DB.Open (":memory:");
      Now   : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Info  : constant Agent_Info :=
        (Name      => To_Unbounded_String ("test-agent"),
         Node_Id   => To_Unbounded_String ("node-001"),
         State     => Registered,
         Last_Seen => Now);
      Map   : Agent_Maps.Map;
      Cur   : Agent_Maps.Cursor;
      Loaded : Agent_Info;
   begin
      Repo.Register (D, Info);
      Map := Repo.Load_All (D);
      Assert (Natural (Map.Length) = 1, "Should have one agent after register");
      Cur := Map.Find ("test-agent");
      Assert (Agent_Maps.Has_Element (Cur), "Registered agent should be in map");
      Loaded := Agent_Maps.Element (Cur);
      Assert (To_String (Loaded.Name) = "test-agent",
              "Agent name should match");
      Assert (To_String (Loaded.Node_Id) = "node-001",
              "Node ID should match");
      Assert (Loaded.State = Registered,
              "Agent state should be Registered");
      Assert (Format_Time (Loaded.Last_Seen) = Format_Time (Now),
              "Last_Seen should match");
   end Test_Register_And_Load_All;

   ---------
   --  Register duplicate
   ---------

   procedure Test_Register_Duplicate_Raises
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      Now  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Info : constant Agent_Info :=
        (Name      => To_Unbounded_String ("dup-agent"),
         Node_Id   => To_Unbounded_String ("node-001"),
         State     => Registered,
         Last_Seen => Now);
      Got_Error : Boolean := False;
   begin
      Repo.Register (D, Info);
      begin
         Repo.Register (D, Info);
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
              "Duplicate register should have raised Database_Error");
   end Test_Register_Duplicate_Raises;

   ---------
   --  Touch updates last_seen
   ---------

   procedure Test_Touch_Updates_Last_Seen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D     : DB.DB_Handle := DB.Open (":memory:");
      Now   : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Later : constant Ada.Calendar.Time := Now + 60.0;
      Info  : constant Agent_Info :=
        (Name      => To_Unbounded_String ("touch-agent"),
         Node_Id   => To_Unbounded_String ("node-001"),
         State     => Registered,
         Last_Seen => Now);
      Map   : Agent_Maps.Map;
      Cur   : Agent_Maps.Cursor;
      Loaded : Agent_Info;
   begin
      Repo.Register (D, Info);
      Repo.Touch (D, (Name      => To_Unbounded_String ("touch-agent"),
                       Node_Id   => To_Unbounded_String ("node-001"),
                       State     => Registered,
                       Last_Seen => Later));
      Map := Repo.Load_All (D);
      Cur := Map.Find ("touch-agent");
      Assert (Agent_Maps.Has_Element (Cur), "Agent should be in map after touch");
      Loaded := Agent_Maps.Element (Cur);
      Assert (Format_Time (Loaded.Last_Seen) = Format_Time (Later),
              "Last_Seen should be updated to later time");
   end Test_Touch_Updates_Last_Seen;

   ---------
   --  Touch not found
   ---------

   procedure Test_Touch_Not_Found_Raises
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Now     : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Got_Error : Boolean := False;
   begin
      begin
         Repo.Touch (D, (Name      => To_Unbounded_String ("nonexistent"),
                          Node_Id   => To_Unbounded_String (""),
                          State     => Registered,
                          Last_Seen => Now));
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert (Err.Kind = DB.Not_Found,
                       "Touch of unknown agent should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert (Got_Error,
              "Touch of unknown agent should have raised Database_Error");
   end Test_Touch_Not_Found_Raises;

   ---------
   --  Set_State updates state
   ---------

   procedure Test_Set_State_Updates_State
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D     : DB.DB_Handle := DB.Open (":memory:");
      Now   : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Info  : constant Agent_Info :=
        (Name      => To_Unbounded_String ("state-agent"),
         Node_Id   => To_Unbounded_String ("node-001"),
         State     => Registered,
         Last_Seen => Now);
      Map   : Agent_Maps.Map;
      Cur   : Agent_Maps.Cursor;
      Loaded : Agent_Info;
   begin
      Repo.Register (D, Info);
      Repo.Set_State (D, (Name      => To_Unbounded_String ("state-agent"),
                           Node_Id   => To_Unbounded_String ("node-001"),
                           State     => Unresponsive,
                           Last_Seen => Now));
      Map := Repo.Load_All (D);
      Cur := Map.Find ("state-agent");
      Assert (Agent_Maps.Has_Element (Cur),
              "Agent should be in map after set_state");
      Loaded := Agent_Maps.Element (Cur);
      Assert (Loaded.State = Unresponsive,
              "Agent state should be Unresponsive");
   end Test_Set_State_Updates_State;

   ---------
   --  Set_State not found
   ---------

   procedure Test_Set_State_Not_Found_Raises
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      Now       : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Got_Error : Boolean := False;
   begin
      begin
         Repo.Set_State (D, (Name      => To_Unbounded_String ("nonexistent"),
                              Node_Id   => To_Unbounded_String (""),
                              State     => Lost,
                              Last_Seen => Now));
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert (Err.Kind = DB.Not_Found,
                       "Set_State on unknown agent should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert (Got_Error,
              "Set_State on unknown agent should have raised Database_Error");
   end Test_Set_State_Not_Found_Raises;

   ---------
   --  Remove deletes agent
   ---------

   procedure Test_Remove_Deletes_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      Now  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Info : constant Agent_Info :=
        (Name      => To_Unbounded_String ("remove-agent"),
         Node_Id   => To_Unbounded_String ("node-001"),
         State     => Registered,
         Last_Seen => Now);
      Map  : Agent_Maps.Map;
   begin
      Repo.Register (D, Info);
      Repo.Remove (D, (Name      => To_Unbounded_String ("remove-agent"),
                        Node_Id   => To_Unbounded_String ("node-001"),
                        State     => Registered,
                        Last_Seen => Now));
      Map := Repo.Load_All (D);
      Assert (Natural (Map.Length) = 0,
              "All agents should be removed");
   end Test_Remove_Deletes_Agent;

   ---------
   --  Remove not found is no-op
   ---------

   procedure Test_Remove_Not_Found_Noop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D    : DB.DB_Handle := DB.Open (":memory:");
      Now  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Info : constant Agent_Info :=
        (Name      => To_Unbounded_String ("keep-agent"),
         Node_Id   => To_Unbounded_String ("node-001"),
         State     => Registered,
         Last_Seen => Now);
      Map  : Agent_Maps.Map;
   begin
      Repo.Register (D, Info);
      --  Remove a different (non-existent) agent
      Repo.Remove (D, (Name      => To_Unbounded_String ("nonexistent"),
                        Node_Id   => To_Unbounded_String (""),
                        State     => Registered,
                        Last_Seen => Now));
      Map := Repo.Load_All (D);
      Assert (Natural (Map.Length) = 1,
               "Original agent should still exist after " &
               "removing unknown agent");
   end Test_Remove_Not_Found_Noop;

   ---------
   --  Register tests
   ---------

   overriding procedure Register_Tests (T : in out Repository_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Register_And_Load_All'Access,
         "Register an agent and verify it appears in Load_All");
      Register_Routine
        (T, Test_Register_Duplicate_Raises'Access,
         "Register duplicate agent raises Constraint_Violation");
      Register_Routine
        (T, Test_Touch_Updates_Last_Seen'Access,
         "Touch updates an agent's last_seen timestamp");
      Register_Routine
        (T, Test_Touch_Not_Found_Raises'Access,
         "Touch on unknown agent raises Not_Found");
      Register_Routine
        (T, Test_Set_State_Updates_State'Access,
         "Set_State updates an agent's state");
      Register_Routine
        (T, Test_Set_State_Not_Found_Raises'Access,
         "Set_State on unknown agent raises Not_Found");
      Register_Routine
        (T, Test_Remove_Deletes_Agent'Access,
         "Remove deletes an agent from the database");
      Register_Routine
        (T, Test_Remove_Not_Found_Noop'Access,
         "Remove on unknown agent is a no-op");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Repository_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Agent.Repository_Tests;
