--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  DI-seam tests for the Scheduler's Strategy parameter. Each test injects
--  a test-only Strategy_Type implementation to verify that Schedule persists
--  exactly the agent the strategy chose (or leaves the entry unscheduled when
--  the strategy returns no agent).

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Scheduler;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Strategies;
with Podmander.Database;
with Podmander.Types;

package body Podmander.Controller.Scheduler_Seam_Tests is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package DB renames Podmander.Database;
   package Svc_Repo renames Podmander.Controller.Service.Repository;
   package Agent_Repo renames Podmander.Controller.Agent.Repository;
   package Scheduler renames Podmander.Controller.Scheduler;
   use Podmander.Controller.Strategies;

   use type Scheduler.Schedule_Error;

   --  Test-only strategy: always returns the fixed agent id it was initialised
   --  with. Does not touch DB.
   type Fixed_Agent_Strategy is new Strategy_Type with record
      Fixed_Id : Podmander.Controller.Agent_Id_Type;
   end record;

   overriding
   function Select_Agent
     (Strategy       : Fixed_Agent_Strategy;
      DB             : in out Podmander.Database.DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Podmander.Controller.Agent_Option
   is
      pragma Unreferenced (DB, Service_Id, Target_Version);
   begin
      return (Present => True, Agent_Id => Strategy.Fixed_Id);
   end Select_Agent;

   --  Test-only strategy: always reports no eligible agent.
   type No_Agent_Strategy is new Strategy_Type with null record;

   overriding
   function Select_Agent
     (Strategy       : No_Agent_Strategy;
      DB             : in out Podmander.Database.DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Podmander.Controller.Agent_Option
   is
      pragma Unreferenced (Strategy, DB, Service_Id, Target_Version);
   begin
      return (Present => False);
   end Select_Agent;

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

   function Seed_Agent
     (Handle : in out DB.DB_Handle; Name : String)
      return Podmander.Controller.Agent_Id_Type
   is
      Info : constant Podmander.Types.Agent_Info :=
        (Id        => 0,
         Name      => To_Unbounded_String (Name),
         Node_Id   => To_Unbounded_String ("node-" & Name),
         State     => Podmander.Types.Registered,
         Last_Seen => Clock);
   begin
      Agent_Repo.Register (Handle, Info);
      return
        Podmander.Controller.Agent_Id_Type
          (Agent_Repo.Load_All (Handle).Element (Name).Id);
   end Seed_Agent;

   -----------------------------------------------
   -- Test_Schedule_Persists_Strategy_Agent
   -----------------------------------------------

   procedure Test_Schedule_Persists_Strategy_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D        : DB.DB_Handle := DB.Open (":memory:");
      Svc      : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "app");
      Agent    : constant Podmander.Controller.Agent_Id_Type :=
        Seed_Agent (D, "agent-1");
      Strategy : constant Fixed_Agent_Strategy :=
        Fixed_Agent_Strategy'(Fixed_Id => Agent);
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
        (Result.Catalog_Entry.Agent_Id = Agent,
         "Scheduler should persist the agent chosen by the injected strategy");
   end Test_Schedule_Persists_Strategy_Agent;

   -----------------------------------------------
   -- Test_Schedule_Unscheduled_On_No_Agent
   -----------------------------------------------

   procedure Test_Schedule_Unscheduled_On_No_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D        : DB.DB_Handle := DB.Open (":memory:");
      Svc      : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "app");
      Strategy : No_Agent_Strategy;
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
         "Schedule should succeed even when strategy returns no agent");
      Assert (Result.Error = Scheduler.None, "Error should be None");
      Assert
        (Result.Catalog_Entry.Agent_Id = 0,
         "Catalog entry should be unscheduled (Agent_Id = 0) when strategy returns no agent");
   end Test_Schedule_Unscheduled_On_No_Agent;

   overriding
   procedure Register_Tests (T : in out Seam_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Schedule_Persists_Strategy_Agent'Access,
         "Scheduler persists agent chosen by injected strategy");
      Register_Routine
        (T,
         Test_Schedule_Unscheduled_On_No_Agent'Access,
         "Scheduler leaves entry unscheduled when strategy returns no agent");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Seam_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Scheduler_Seam_Tests;
