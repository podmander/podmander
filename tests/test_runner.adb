--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Run;
with AUnit.Reporter.Text;
with AUnit.Test_Suites;
with Podmander.Controller_Tests;
with Podmander.Messages_Tests;

procedure Test_Runner is

   function All_Suites return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Podmander.Messages_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Podmander.Controller_Tests.Suite);
      return Result;
   end All_Suites;

   procedure Run is new AUnit.Run.Test_Runner (All_Suites);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Run (Reporter);
end Test_Runner;
