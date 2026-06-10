--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Node.Repository;
with Podmander.Controller.Strategies.First_Available;
with Podmander.Database;
with Podmander.Types;

package body Podmander.Controller.Strategies.First_Available_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Database;
    package Agent_Repo renames Podmander.Controller.Agent.Repository;
    package Node_Repo renames Podmander.Controller.Node.Repository;
    package FA renames Podmander.Controller.Strategies.First_Available;

   use type Podmander.Types.Agent_State;

   type Strategy_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Strategy_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Strategies.First_Available"));

   overriding
   procedure Register_Tests (T : in out Strategy_Test);

   --  Register an agent; if State differs from Registered, update it after
   --  registration so the DB row has the requested state.
    procedure Seed_Agent
      (Handle : in out DB.DB_Handle;
       Name   : String;
       State  : Podmander.Types.Agent_State := Podmander.Types.Registered)
    is
       Node_Id : constant Podmander.Types.Node_Id_Type := Node_Repo.Create_Or_Get (Handle, Name);
       Info    : constant Podmander.Types.Agent_Info :=
         (Id            => 0,
          Name          => To_Unbounded_String (Name),
          Connection_Id => To_Unbounded_String ("node-" & Name),
          State         => Podmander.Types.Registered,
          Last_Seen     => Clock,
          Node_Id       => Node_Id);
   begin
      Agent_Repo.Register (Handle, Info);
      if State /= Podmander.Types.Registered then
         declare
            All_Agents : constant Podmander.Types.Agent_Maps.Map :=
              Agent_Repo.Load_All (Handle);
            Modified   : Podmander.Types.Agent_Info :=
              All_Agents.Element (Name);
         begin
            Modified.State := State;
            Agent_Repo.Set_State (Handle, Modified);
         end;
      end if;
   end Seed_Agent;

   ------------------------------------
   -- Test_No_Agents_Returns_No_Agent
   ------------------------------------

   procedure Test_No_Agents_Returns_No_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Podmander.Controller.Agent_Option;
   begin
      Result :=
        FA.Instance.Select_Agent
          (DB             => D,
           Service_Id     => Podmander.Controller.Service_Id_Type'First,
           Target_Version => Podmander.Controller.Service_Version_Type'First);
      Assert (not Result.Present, "No agents should return Present => False");
   end Test_No_Agents_Returns_No_Agent;

   ------------------------------------------
   -- Test_One_Registered_Agent_Returns_It
   ------------------------------------------

   procedure Test_One_Registered_Agent_Returns_It
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Podmander.Controller.Agent_Option;
   begin
      Seed_Agent (D, "agent-1");
      Result :=
        FA.Instance.Select_Agent
          (DB             => D,
           Service_Id     => Podmander.Controller.Service_Id_Type'First,
           Target_Version => Podmander.Controller.Service_Version_Type'First);
      Assert
        (Result.Present, "One registered agent should return Present => True");
      Assert (Result.Agent_Id > 0, "Agent_Id should be positive");
   end Test_One_Registered_Agent_Returns_It;

   -------------------------------------------
   -- Test_Multiple_Agents_Returns_A_Registered
   -------------------------------------------

   procedure Test_Multiple_Agents_Returns_A_Registered
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Podmander.Controller.Agent_Option;
   begin
      Seed_Agent (D, "agent-1");
      Seed_Agent (D, "agent-2");
      Result :=
        FA.Instance.Select_Agent
          (DB             => D,
           Service_Id     => Podmander.Controller.Service_Id_Type'First,
           Target_Version => Podmander.Controller.Service_Version_Type'First);
      Assert
        (Result.Present,
         "Multiple registered agents should return Present => True");
      Assert (Result.Agent_Id > 0, "Agent_Id should be assigned");
   end Test_Multiple_Agents_Returns_A_Registered;

   ----------------------------------------
   -- Test_Unresponsive_Agent_Is_Skipped
   ----------------------------------------

   procedure Test_Unresponsive_Agent_Is_Skipped
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D      : DB.DB_Handle := DB.Open (":memory:");
      Result : Podmander.Controller.Agent_Option;
   begin
      Seed_Agent (D, "agent-1", Podmander.Types.Unresponsive);
      Result :=
        FA.Instance.Select_Agent
          (DB             => D,
           Service_Id     => Podmander.Controller.Service_Id_Type'First,
           Target_Version => Podmander.Controller.Service_Version_Type'First);
      Assert
        (not Result.Present,
         "Non-Registered agent should be skipped (Present => False)");
   end Test_Unresponsive_Agent_Is_Skipped;

   overriding
   procedure Register_Tests (T : in out Strategy_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_No_Agents_Returns_No_Agent'Access,
         "No agents returns Present => False");
      Register_Routine
        (T,
         Test_One_Registered_Agent_Returns_It'Access,
         "One registered agent returns that agent");
      Register_Routine
        (T,
         Test_Multiple_Agents_Returns_A_Registered'Access,
         "Multiple agents returns a registered agent");
      Register_Routine
        (T,
         Test_Unresponsive_Agent_Is_Skipped'Access,
         "Non-Registered agent is skipped");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Strategy_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Strategies.First_Available_Tests;
