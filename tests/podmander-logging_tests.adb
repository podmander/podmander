--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Logging;

package body Podmander.Logging_Tests is

   use AUnit.Assertions;

   type Logging_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Logging_Test) return AUnit.Message_String
   is (AUnit.Format ("Logging"));

   overriding
   procedure Register_Tests (T : in out Logging_Test);

   procedure Test_Debug_Suppressed_At_Info
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Logging.Set_Level (Podmander.Logging.Info);
      Podmander.Logging.Debug ("test", "should not appear");
      Assert (True, "Debug suppressed without crash");
   end Test_Debug_Suppressed_At_Info;

   procedure Test_Info_Emitted_At_Info
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Logging.Set_Level (Podmander.Logging.Info);
      Podmander.Logging.Info ("test", "info message");
      Assert (True, "Info emitted without crash");
   end Test_Info_Emitted_At_Info;

   procedure Test_Warning_Emitted_At_Info
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Logging.Set_Level (Podmander.Logging.Info);
      Podmander.Logging.Warning ("test", "warning message");
      Assert (True, "Warning emitted without crash");
   end Test_Warning_Emitted_At_Info;

   procedure Test_All_Levels_At_Debug
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Logging.Set_Level (Podmander.Logging.Debug);
      Podmander.Logging.Debug ("test", "debug");
      Podmander.Logging.Info ("test", "info");
      Podmander.Logging.Warning ("test", "warning");
      Podmander.Logging.Error ("test", "error");
      Podmander.Logging.Critical ("test", "critical");
      Assert (True, "All levels emitted without crash");
   end Test_All_Levels_At_Debug;

   procedure Test_Critical_Emitted_At_Critical
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Logging.Set_Level (Podmander.Logging.Critical);
      Podmander.Logging.Critical ("test", "critical only");
      Assert (True, "Critical emitted at Critical level");
   end Test_Critical_Emitted_At_Critical;

   procedure Test_Error_Suppressed_At_Critical
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Logging.Set_Level (Podmander.Logging.Critical);
      Podmander.Logging.Error ("test", "should not appear");
      Assert (True, "Error suppressed at Critical level");
   end Test_Error_Suppressed_At_Critical;

   procedure Test_Output_Can_Be_Disabled
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Logging.Set_Output_Enabled (False);
      Assert
        (not Podmander.Logging.Output_Enabled,
         "Logging output should be disabled");

      Podmander.Logging.Set_Output_Enabled (True);
      Assert
        (Podmander.Logging.Output_Enabled, "Logging output should be enabled");

      Podmander.Logging.Set_Output_Enabled (False);
   end Test_Output_Can_Be_Disabled;

   overriding
   procedure Register_Tests (T : in out Logging_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Debug_Suppressed_At_Info'Access, "Debug suppressed at Info");
      Register_Routine
        (T, Test_Info_Emitted_At_Info'Access, "Info emitted at Info");
      Register_Routine
        (T, Test_Warning_Emitted_At_Info'Access, "Warning emitted at Info");
      Register_Routine
        (T, Test_All_Levels_At_Debug'Access, "All levels at Debug");
      Register_Routine
        (T,
         Test_Critical_Emitted_At_Critical'Access,
         "Critical at Critical level");
      Register_Routine
        (T,
         Test_Error_Suppressed_At_Critical'Access,
         "Error suppressed at Critical");
      Register_Routine
        (T, Test_Output_Can_Be_Disabled'Access, "Output can be disabled");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Logging_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Logging_Tests;
