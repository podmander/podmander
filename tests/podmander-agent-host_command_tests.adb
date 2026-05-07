--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Agent.Host_Command;

package body Podmander.Agent.Host_Command_Tests is

   use AUnit.Assertions;
   use Podmander.Agent.Host_Command;

   package SU renames Ada.Strings.Unbounded;

   function Contains
     (Text : SU.Unbounded_String;
      Sub  : String) return Boolean
   is (Ada.Strings.Fixed.Index (SU.To_String (Text), Sub) > 0);

   type Command_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name
     (T : Command_Test) return AUnit.Message_String
   is (AUnit.Format ("Host_Command"));

   overriding procedure Register_Tests (T : in out Command_Test);

   procedure Test_Run_Echo_Success
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args : constant Argument_List (1 .. 1) := [1 => +"hello"];
      Result : constant Command_Result :=
        Run_Command ("/bin/echo", Args);
   begin
      Assert (Result.State = Exited, "Expected Exited state");
      Assert (Result.Exit_Status = 0, "Expected exit status 0");
      Assert (Contains (Result.Output, "hello"),
              "Expected output to contain 'hello'");
   end Test_Run_Echo_Success;

   procedure Test_Run_False_Nonzero
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args   : Argument_List (1 .. 0);
      Result : constant Command_Result :=
        Run_Command ("/bin/false", Args);
   begin
      Assert (Result.State = Exited, "Expected Exited state");
      Assert (Result.Exit_Status /= 0, "Expected non-zero exit status");
   end Test_Run_False_Nonzero;

   procedure Test_Run_Nonexistent_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args   : Argument_List (1 .. 0);
      Result : constant Command_Result :=
        Run_Command ("/nonexistent_cmd_12345", Args);
   begin
      Assert (Result.State = Error, "Expected Error state");
   end Test_Run_Nonexistent_Error;

   procedure Test_Run_Stderr_Separate
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args : constant Argument_List (1 .. 2) :=
        [1 => +"-c", 2 => +"echo err >&2"];
      Result : constant Command_Result :=
        Run_Command ("/bin/sh", Args, Err_To_Out => False);
   begin
      Assert (Result.State = Exited, "Expected Exited state");
      Assert (Contains (Result.Error_Output, "err"),
              "Expected stderr to contain 'err'");
   end Test_Run_Stderr_Separate;

   procedure Test_Run_Stderr_Merged
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args : constant Argument_List (1 .. 2) :=
        [1 => +"-c", 2 => +"echo out && echo err >&2"];
      Result : constant Command_Result :=
        Run_Command ("/bin/sh", Args, Err_To_Out => True);
   begin
      Assert (Result.State = Exited, "Expected Exited state");
      Assert (Contains (Result.Output, "out"),
              "Expected merged output to contain 'out'");
      Assert (Contains (Result.Output, "err"),
              "Expected merged output to contain 'err'");
   end Test_Run_Stderr_Merged;

   procedure Test_Run_Shell_Echo
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Command_Result :=
        Run_Command_Shell ("echo hello");
   begin
      Assert (Result.State = Exited, "Expected Exited state");
      Assert (Result.Exit_Status = 0, "Expected exit status 0");
      Assert (Contains (Result.Output, "hello"),
              "Expected output to contain 'hello'");
   end Test_Run_Shell_Echo;

   procedure Test_Run_Shell_Pipeline
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Command_Result :=
        Run_Command_Shell ("echo hello | tr h H");
   begin
      Assert (Result.State = Exited, "Expected Exited state");
      Assert (Contains (Result.Output, "Hello"),
              "Expected output to contain 'Hello'");
   end Test_Run_Shell_Pipeline;

   procedure Test_Run_Many_Args
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args : constant Argument_List (1 .. 12) :=
        [+"a01", +"a02", +"a03", +"a04",
         +"a05", +"a06", +"a07", +"a08",
         +"a09", +"a10", +"a11", +"a12"];
      Result : constant Command_Result :=
        Run_Command ("/bin/echo", Args);
   begin
      Assert (Result.State = Exited, "Expected Exited state");
      Assert (Result.Exit_Status = 0, "Expected exit status 0");
      Assert (Contains (Result.Output, "a01"),
              "Expected output to contain first arg");
      Assert (Contains (Result.Output, "a12"),
              "Expected output to contain last arg");
   end Test_Run_Many_Args;

   overriding procedure Register_Tests (T : in out Command_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Run_Echo_Success'Access,
         "Run echo returns Exited with output");
      Register_Routine
        (T, Test_Run_False_Nonzero'Access,
         "Run false returns Exited with non-zero status");
      Register_Routine
        (T, Test_Run_Nonexistent_Error'Access,
         "Run nonexistent returns Error state");
      Register_Routine
        (T, Test_Run_Stderr_Separate'Access,
         "Stderr captured separately when Err_To_Out=False");
      Register_Routine
        (T, Test_Run_Stderr_Merged'Access,
         "Stderr merged into Output when Err_To_Out=True");
      Register_Routine
        (T, Test_Run_Shell_Echo'Access,
         "Run_Command_Shell echoes correctly");
      Register_Routine
        (T, Test_Run_Shell_Pipeline'Access,
         "Run_Command_Shell supports pipes");
      Register_Routine
        (T, Test_Run_Many_Args'Access,
         "Run_Command handles many arguments without truncation");
   end Register_Tests;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, new Command_Test);
      return Result;
   end Suite;

end Podmander.Agent.Host_Command_Tests;
