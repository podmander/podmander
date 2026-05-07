--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Text_IO;
with Podmander.Agent.Host_Command;
with Podmander.Agent.Host_Command.Result_Mapping;
with Podmander.Logging;
with Podmander.Messages.Result_Codes;
with Podmander.Messages.Status_Responses;

package body Podmander.Agent.Podman is

   use Ada.Strings.Unbounded;
   use Podmander.Messages.Deploy_Results;
   use type Podmander.Messages.Result_Codes.Result_Code;
   package HC renames Podmander.Agent.Host_Command;
   package RM renames Podmander.Agent.Host_Command.Result_Mapping;
   package RC renames Podmander.Messages.Result_Codes;

   function Install_Quadlet
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
   begin
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
         Reload_Args : constant HC.Argument_List :=
           [HC."+"("--user"), HC."+"("daemon-reload")];
         Result : constant HC.Command_Result :=
           HC.Run_Command
             (Program    => "/usr/bin/systemctl",
              Args       => Reload_Args,
              Err_To_Out => True);
         Code : constant RC.Result_Code := RM.To_Result_Code (Result);
      begin
         if Code /= RC.Ok then
            Podmander.Logging.Error
              ("agent", "daemon-reload failed for " & Service_Name);
            return Deploy_Result'
              (Code          => Code,
               Service_Name  => To_Unbounded_String (Service_Name),
               Error_Message =>
                 To_Unbounded_String ("daemon-reload failed"));
         end if;
      end Daemon_Reload;

      Start_Service :
      declare
         Start_Args : constant HC.Argument_List :=
           [HC."+"("--user"),
            HC."+"("start"),
            HC."+"(Service_Name & ".service")];
         Result : constant HC.Command_Result :=
           HC.Run_Command
             (Program    => "/usr/bin/systemctl",
              Args       => Start_Args,
              Err_To_Out => True);
         Code : constant RC.Result_Code := RM.To_Result_Code (Result);
      begin
         if Code /= RC.Ok then
            Podmander.Logging.Error
              ("agent", "systemctl start failed for " & Service_Name);
            return Deploy_Result'
              (Code          => Code,
               Service_Name  => To_Unbounded_String (Service_Name),
               Error_Message =>
                 To_Unbounded_String ("systemctl start failed"));
         end if;
      end Start_Service;

      Podmander.Logging.Info
        ("agent", "Deployed " & Service_Name & " successfully");
      return Deploy_Result'
        (Code          => RC.Ok,
         Service_Name  => To_Unbounded_String (Service_Name),
         Error_Message => To_Unbounded_String (""));
   exception
      when E : others =>
         Podmander.Logging.Error
           ("agent",
            "Deploy exception for " & Service_Name
            & " [" & Ada.Exceptions.Exception_Name (E) & "]: "
            & Ada.Exceptions.Exception_Message (E));
         return Deploy_Result'
           (Code          => RC.Internal,
            Service_Name  => To_Unbounded_String (Service_Name),
            Error_Message => To_Unbounded_String
              (Ada.Exceptions.Exception_Name (E)
               & ": "
               & Ada.Exceptions.Exception_Message (E)));
   end Install_Quadlet;

   function List_Containers
     return Podmander.Messages.Status_Responses.Status_Response
   is
      use Podmander.Messages.Status_Responses;
      Ps_Args : constant HC.Argument_List :=
        [HC."+"("ps"),
         HC."+"("--format"),
         HC."+"("{{.Names}} {{.Status}}")];
      Result : constant HC.Command_Result :=
        HC.Run_Command
          (Program    => "/usr/bin/podman",
           Args       => Ps_Args,
           Err_To_Out => False);
      Code : constant RC.Result_Code := RM.To_Result_Code (Result);
   begin
      if Code = RC.Ok then
         Podmander.Logging.Info
           ("agent", "Status query: sending container list");
         return Status_Response'
           (Code          => Code,
            Containers    => Result.Output,
            Error_Message => Null_Unbounded_String);
      else
         Podmander.Logging.Warning
           ("agent", "Status query: podman ps failed");
         declare
            Error_Detail : constant Unbounded_String :=
              (if Length (Result.Error_Output) > 0
               then Result.Error_Output
               else Result.Output);
         begin
            return Status_Response'
              (Code          => Code,
               Containers    => Null_Unbounded_String,
               Error_Message => Error_Detail);
         end;
      end if;
   exception
      when E : others =>
         Podmander.Logging.Error
           ("agent",
            "Status query exception ["
            & Ada.Exceptions.Exception_Name (E) & "]: "
            & Ada.Exceptions.Exception_Message (E));
         return Status_Response'
           (Code          => RC.Internal,
            Containers    => Null_Unbounded_String,
            Error_Message => To_Unbounded_String
              (Ada.Exceptions.Exception_Name (E)
               & ": "
               & Ada.Exceptions.Exception_Message (E)));
   end List_Containers;

end Podmander.Agent.Podman;
