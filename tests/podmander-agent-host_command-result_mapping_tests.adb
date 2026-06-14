--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Agent.Host_Command.Result_Mapping;
with Podmander.Messages.Result_Codes;

package body Podmander.Agent.Host_Command.Result_Mapping_Tests is

   use AUnit.Assertions;
   use type Podmander.Messages.Result_Codes.Result_Code;

   package SU renames Ada.Strings.Unbounded;
   package RC renames Podmander.Messages.Result_Codes;
   package RM renames Podmander.Agent.Host_Command.Result_Mapping;

   Empty : constant SU.Unbounded_String := SU.Null_Unbounded_String;

   type Mapping_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Mapping_Test) return AUnit.Message_String
   is (AUnit.Format ("Host_Command.Result_Mapping"));

   overriding
   procedure Register_Tests (T : in out Mapping_Test);

   procedure Test_Exited_Zero_Maps_Ok
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Command_Result :=
        (State        => Exited,
         Exit_Status  => 0,
         Output       => Empty,
         Error_Output => Empty);
   begin
      Assert
        (RM.To_Result_Code (Result) = RC.Ok, "Exited(0) should map to Ok");
   end Test_Exited_Zero_Maps_Ok;

   procedure Test_Exited_Nonzero_Maps_Failed
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Command_Result :=
        (State        => Exited,
         Exit_Status  => 1,
         Output       => Empty,
         Error_Output => Empty);
   begin
      Assert
        (RM.To_Result_Code (Result) = RC.Failed,
         "Exited(non-zero) should map to Failed");
   end Test_Exited_Nonzero_Maps_Failed;

   procedure Test_Error_Maps_Unavailable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Command_Result :=
        (State        => Error,
         Error_Code   => 2,
         Output       => Empty,
         Error_Output => Empty);
   begin
      Assert
        (RM.To_Result_Code (Result) = RC.Unavailable,
         "Error should map to Unavailable");
   end Test_Error_Maps_Unavailable;

   procedure Test_Crashed_Maps_Internal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Command_Result :=
        (State        => Crashed,
         Signal       => 11,
         Output       => Empty,
         Error_Output => Empty);
   begin
      Assert
        (RM.To_Result_Code (Result) = RC.Internal,
         "Crashed should map to Internal");
   end Test_Crashed_Maps_Internal;

   procedure Test_Terminated_Maps_Internal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Command_Result :=
        (State        => Terminated,
         Signal       => 15,
         Output       => Empty,
         Error_Output => Empty);
   begin
      Assert
        (RM.To_Result_Code (Result) = RC.Internal,
         "Terminated should map to Internal");
   end Test_Terminated_Maps_Internal;

   overriding
   procedure Register_Tests (T : in out Mapping_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Exited_Zero_Maps_Ok'Access, "Exited(0) maps to Ok");
      Register_Routine
        (T,
         Test_Exited_Nonzero_Maps_Failed'Access,
         "Exited(non-zero) maps to Failed");
      Register_Routine
        (T, Test_Error_Maps_Unavailable'Access, "Error maps to Unavailable");
      Register_Routine
        (T, Test_Crashed_Maps_Internal'Access, "Crashed maps to Internal");
      Register_Routine
        (T,
         Test_Terminated_Maps_Internal'Access,
         "Terminated maps to Internal");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Mapping_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Agent.Host_Command.Result_Mapping_Tests;
