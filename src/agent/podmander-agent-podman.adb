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

package body Podmander.Agent.Podman is

   use Ada.Strings.Unbounded;
   use Podmander.Messages.Deploy_Results;
   use type Podmander.Messages.Result_Codes.Result_Code;
   package HC renames Podmander.Agent.Host_Command;
   package RM renames Podmander.Agent.Host_Command.Result_Mapping;
   package RC renames Podmander.Messages.Result_Codes;

   -- Run a single systemctl step and return True on success.
   -- On failure, returns False and populates Failure_Result with
   -- a Deploy_Result carrying the step's Result_Code, Service_Name,
   -- and Error_Message.
   function Run_Systemctl_Step
     (Args           : HC.Argument_List;
      Step_Label     : String;
      Service_Name   : String;
      Failure_Result : out Deploy_Result) return Boolean
   is
      Cmd_Result : constant HC.Command_Result :=
        HC.Run_Command
          (Program => "/usr/bin/systemctl", Args => Args, Err_To_Out => True);
      Code       : constant RC.Result_Code := RM.To_Result_Code (Cmd_Result);
   begin
      if Code = RC.Ok then
         return True;
      else
         Failure_Result :=
           Deploy_Result'
             (Catalog_Id    => 0,
              Code          => Code,
              Service_Name  => To_Unbounded_String (Service_Name),
              Error_Message => To_Unbounded_String (Step_Label & " failed"));
         return False;
      end if;
   end Run_Systemctl_Step;

   function Install_Quadlet
     (Service_Name : String; Quadlet : String) return Deploy_Result
   is
      Home      : constant String := Ada.Environment_Variables.Value ("HOME");
      Base_Dir  : constant String := Home & "/.config/containers/systemd";
      File_Path : constant String :=
        Base_Dir & "/" & Service_Name & ".container";

      Step_Failure_Result : Deploy_Result;
   begin
      Podmander.Logging.Info ("agent", "Deploying " & Service_Name);

      Ada.Directories.Create_Path (Base_Dir);

      Write_Quadlet :
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, File_Path);
         Ada.Text_IO.Put (File, Quadlet);
         Ada.Text_IO.Close (File);
      end Write_Quadlet;

      if not Run_Systemctl_Step
               ([HC."+" ("--user"), HC."+" ("daemon-reload")],
                "daemon-reload",
                Service_Name,
                Step_Failure_Result)
      then
         Podmander.Logging.Error
           ("agent", "daemon-reload failed for " & Service_Name);
         return Step_Failure_Result;
      end if;

      if not Run_Systemctl_Step
               ([HC."+" ("--user"),
                 HC."+" ("start"),
                 HC."+" (Service_Name & ".service")],
                "systemctl start",
                Service_Name,
                Step_Failure_Result)
      then
         Podmander.Logging.Error
           ("agent", "systemctl start failed for " & Service_Name);
         return Step_Failure_Result;
      end if;

      Podmander.Logging.Info
        ("agent", "Deployed " & Service_Name & " successfully");
      return
        Deploy_Result'
          (Catalog_Id    => 0,
           Code          => RC.Ok,
           Service_Name  => To_Unbounded_String (Service_Name),
           Error_Message => To_Unbounded_String (""));
   exception
      when E : others =>
         Podmander.Logging.Error
           ("agent",
            "Deploy exception for "
            & Service_Name
            & " ["
            & Ada.Exceptions.Exception_Name (E)
            & "]: "
            & Ada.Exceptions.Exception_Message (E));
         return
           Deploy_Result'
             (Catalog_Id    => 0,
              Code          => RC.Internal,
              Service_Name  => To_Unbounded_String (Service_Name),
              Error_Message =>
                To_Unbounded_String
                  (Ada.Exceptions.Exception_Name (E)
                   & ": "
                   & Ada.Exceptions.Exception_Message (E)));
   end Install_Quadlet;

   function List_Containers
      return Podmander.Messages.Status_Responses.Status_Response
   is
      use Podmander.Messages.Status_Responses;
      Ps_Args : constant HC.Argument_List :=
        [HC."+" ("ps"),
         HC."+" ("--format"),
         HC."+" ("{{.Names}} {{.Status}}")];
      Result  : constant HC.Command_Result :=
        HC.Run_Command
          (Program => "/usr/bin/podman", Args => Ps_Args, Err_To_Out => False);
      Code    : constant RC.Result_Code := RM.To_Result_Code (Result);
   begin
      if Code = RC.Ok then
         Podmander.Logging.Info
           ("agent", "Status query: sending container list");
         return
           Status_Response'
             (Code          => Code,
              Containers    => Result.Output,
              Error_Message => Null_Unbounded_String);
      else
         Podmander.Logging.Warning ("agent", "Status query: podman ps failed");
         declare
            Error_Detail : constant Unbounded_String :=
              (if Length (Result.Error_Output) > 0
               then Result.Error_Output
               else Result.Output);
         begin
            return
              Status_Response'
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
            & Ada.Exceptions.Exception_Name (E)
            & "]: "
            & Ada.Exceptions.Exception_Message (E));
         return
           Status_Response'
             (Code          => RC.Internal,
              Containers    => Null_Unbounded_String,
              Error_Message =>
                To_Unbounded_String
                  (Ada.Exceptions.Exception_Name (E)
                   & ": "
                   & Ada.Exceptions.Exception_Message (E)));
   end List_Containers;

end Podmander.Agent.Podman;
