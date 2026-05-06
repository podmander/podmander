--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Podmander.Logging;

package body Podmander.Agent.Deployer is

   use Ada.Strings.Unbounded;
   use Podmander.Messages.Deploy_Results;

   function Execute_Deploy
     (Service_Name : String;
      Quadlet      : String)
      return Deploy_Result
   is
      Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME");
      Base_Dir  : constant String :=
        Home & "/.config/containers/systemd";
      File_Path : constant String :=
        Base_Dir & "/" & Service_Name & ".container";
      Result    : Deploy_Result;
   begin
      Result.Service_Name := To_Unbounded_String (Service_Name);

      Podmander.Logging.Info
        ("agent", "Deploying " & Service_Name);

      Ada.Directories.Create_Path (Base_Dir);

      Write_Quadlet :
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (File, Ada.Text_IO.Out_File, File_Path);
         Ada.Text_IO.Put (File, Quadlet);
         Ada.Text_IO.Close (File);
      end Write_Quadlet;

      Daemon_Reload :
      declare
         Args    : GNAT.OS_Lib.Argument_List (1 .. 2);
         Success : Boolean;
      begin
         Args (1) := new String'("--user");
         Args (2) := new String'("daemon-reload");
         GNAT.OS_Lib.Spawn
           ("/usr/bin/systemctl", Args, Success);
         for J in Args'Range loop
            GNAT.OS_Lib.Free (Args (J));
         end loop;
         if not Success then
            Result.Success := False;
            Result.Error_Message :=
              To_Unbounded_String ("daemon-reload failed");
            Podmander.Logging.Error
              ("agent", "daemon-reload failed for " & Service_Name);
            return Result;
         end if;
      end Daemon_Reload;

      Start_Service :
      declare
         Args    : GNAT.OS_Lib.Argument_List (1 .. 3);
         Success : Boolean;
      begin
         Args (1) := new String'("--user");
         Args (2) := new String'("start");
         Args (3) := new String'(Service_Name & ".service");
         GNAT.OS_Lib.Spawn
           ("/usr/bin/systemctl", Args, Success);
         for J in Args'Range loop
            GNAT.OS_Lib.Free (Args (J));
         end loop;
         if not Success then
            Result.Success := False;
            Result.Error_Message :=
              To_Unbounded_String ("systemctl start failed");
            Podmander.Logging.Error
              ("agent", "systemctl start failed for " & Service_Name);
            return Result;
         end if;
      end Start_Service;

      Result.Success := True;
      Result.Error_Message := To_Unbounded_String ("");
      Podmander.Logging.Info
        ("agent", "Deployed " & Service_Name & " successfully");
      return Result;
   exception
      when E : others =>
         Result.Success := False;
         Result.Error_Message := To_Unbounded_String
           (Ada.Exceptions.Exception_Message (E));
         return Result;
   end Execute_Deploy;

end Podmander.Agent.Deployer;
