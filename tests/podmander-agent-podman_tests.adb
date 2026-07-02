--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Agent.Host_Command;
with Podmander.Agent.Podman;
with Podmander.Messages.Result_Codes;
with Podmander.Messages.Status_Responses;

package body Podmander.Agent.Podman_Tests is

   use AUnit.Assertions;
   use type Podmander.Agent.Host_Command.Command_Termination;
   use type Podmander.Agent.Host_Command.Exit_Status;
   use type Podmander.Messages.Result_Codes.Result_Code;

   package HC renames Podmander.Agent.Host_Command;
   package RC renames Podmander.Messages.Result_Codes;
   package SU renames Ada.Strings.Unbounded;

   Test_Dir : constant String := "/tmp/podmander-podman-tests";

   type Path_Guard is limited record
      Path_Changed : Boolean := False;
      Had_Path     : Boolean := False;
      Old_Path     : SU.Unbounded_String;
   end record;

   function Contains (Text : SU.Unbounded_String; Sub : String) return Boolean
   is (Ada.Strings.Fixed.Index (SU.To_String (Text), Sub) > 0);

   procedure Set_Test_Path (Guard : in out Path_Guard; Path : String) is
   begin
      Guard.Had_Path := Ada.Environment_Variables.Exists ("PATH");
      if Guard.Had_Path then
         Guard.Old_Path :=
           SU.To_Unbounded_String (Ada.Environment_Variables.Value ("PATH"));
      end if;

      Ada.Environment_Variables.Set ("PATH", Path);
      Guard.Path_Changed := True;
   end Set_Test_Path;

   procedure Restore_Path (Guard : Path_Guard) is
   begin
      if not Guard.Path_Changed then
         return;
      end if;

      if Guard.Had_Path then
         Ada.Environment_Variables.Set ("PATH", SU.To_String (Guard.Old_Path));
      else
         Ada.Environment_Variables.Clear ("PATH");
      end if;
   end Restore_Path;

   procedure Prepare_Test_Dir is
   begin
      if Ada.Directories.Exists (Test_Dir & "/podman") then
         Ada.Directories.Delete_File (Test_Dir & "/podman");
      end if;
      if not Ada.Directories.Exists (Test_Dir) then
         Ada.Directories.Create_Path (Test_Dir);
      end if;
   end Prepare_Test_Dir;

   procedure Write_Fake_Podman (Successful : Boolean) is
      File : Ada.Text_IO.File_Type;
   begin
      Prepare_Test_Dir;
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Test_Dir & "/podman");
      Ada.Text_IO.Put_Line (File, "#!/bin/sh");
      Ada.Text_IO.Put_Line (File, "if [ ""$1"" = ""ps"" ]; then");
      if Successful then
         Ada.Text_IO.Put_Line (File, "  echo demo Up 1 second");
         Ada.Text_IO.Put_Line (File, "  exit 0");
      else
         Ada.Text_IO.Put_Line (File, "  echo podman failed >&2");
         Ada.Text_IO.Put_Line (File, "  exit 42");
      end if;
      Ada.Text_IO.Put_Line (File, "fi");
      Ada.Text_IO.Put_Line (File, "echo unexpected arguments: ""$@"" >&2");
      Ada.Text_IO.Put_Line (File, "exit 42");
      Ada.Text_IO.Close (File);

      declare
         Args   : constant HC.Argument_List :=
           [HC."+" ("755"), HC."+" (Test_Dir & "/podman")];
         Result : constant HC.Command_Result :=
           HC.Run_Command ("/bin/chmod", Args);
      begin
         Assert (Result.Termination = HC.Exited, "chmod should exit");
         Assert (Result.Status = HC.Success, "chmod should succeed");
      end;
   end Write_Fake_Podman;

   type Podman_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Podman_Test) return AUnit.Message_String
   is (AUnit.Format ("Agent.Podman"));

   overriding
   procedure Register_Tests (T : in out Podman_Test);

   procedure Test_List_Containers_Uses_Path_Podman
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Guard : Path_Guard;
   begin
      Write_Fake_Podman (Successful => True);
      Set_Test_Path (Guard, Test_Dir);

      declare
         Result :
           constant Podmander.Messages.Status_Responses.Status_Response :=
             Podmander.Agent.Podman.List_Containers;
      begin
         Restore_Path (Guard);
         Assert (Result.Code = RC.Ok, "fake podman should succeed");
         Assert
           (Contains (Result.Containers, "demo Up 1 second"),
            "container list should come from PATH podman");
      end;
   exception
      when others =>
         Restore_Path (Guard);
         raise;
   end Test_List_Containers_Uses_Path_Podman;

   procedure Test_List_Containers_Reports_Missing_Podman
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Guard : Path_Guard;
   begin
      Prepare_Test_Dir;
      Set_Test_Path (Guard, Test_Dir);

      declare
         Result :
           constant Podmander.Messages.Status_Responses.Status_Response :=
             Podmander.Agent.Podman.List_Containers;
      begin
         Restore_Path (Guard);
         Assert (Result.Code = RC.Unavailable, "missing podman should fail");
      end;
   exception
      when others =>
         Restore_Path (Guard);
         raise;
   end Test_List_Containers_Reports_Missing_Podman;

   procedure Test_List_Containers_Reports_Nonzero_Podman
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Guard : Path_Guard;
   begin
      Write_Fake_Podman (Successful => False);
      Set_Test_Path (Guard, Test_Dir);

      declare
         Result :
           constant Podmander.Messages.Status_Responses.Status_Response :=
             Podmander.Agent.Podman.List_Containers;
      begin
         Restore_Path (Guard);
         Assert (Result.Code = RC.Failed, "failing podman should be Failed");
      end;
   exception
      when others =>
         Restore_Path (Guard);
         raise;
   end Test_List_Containers_Reports_Nonzero_Podman;

   overriding
   procedure Register_Tests (T : in out Podman_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_List_Containers_Uses_Path_Podman'Access,
         "List_Containers uses podman from PATH");
      Register_Routine
        (T,
         Test_List_Containers_Reports_Missing_Podman'Access,
         "List_Containers reports missing podman");
      Register_Routine
        (T,
         Test_List_Containers_Reports_Nonzero_Podman'Access,
         "List_Containers reports non-zero podman");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Podman_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Agent.Podman_Tests;
