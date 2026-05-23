--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Run;
with AUnit.Reporter.Text;
with AUnit.Test_Suites;
with Podmander.Agent.Host_Command_Tests;
with Podmander.Agent.Host_Command.Result_Mapping_Tests;
with Podmander.Controller.Agent.Repository_Tests;
with Podmander.Controller.Registrar_Tests;
with Podmander.Controller.Scheduler_Tests;
with Podmander.Controller.Service.Repository_Tests;
with Podmander.Controller.Service_Catalog.Repository_Tests;
with Podmander.Controller_Tests;
with Podmander.Enrollment_Tests;
with Podmander.Config_Tests;
with Podmander.Database_Tests;
with Podmander.Generators.Quadlet_Tests;
with Podmander.Logging_Tests;
with Podmander.Messages_Tests;

procedure Test_Runner is

   function All_Suites return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Podmander.Agent.Host_Command_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Agent.Host_Command.Result_Mapping_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Messages_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Controller.Agent.Repository_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Controller.Registrar_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Controller.Scheduler_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Controller.Service.Repository_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Controller.Service_Catalog.Repository_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Controller_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Enrollment_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Logging_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Config_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Generators.Quadlet_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Database_Tests.Suite);
      return Result;
   end All_Suites;

   procedure Run is new AUnit.Run.Test_Runner (All_Suites);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Run (Reporter);
end Test_Runner;
