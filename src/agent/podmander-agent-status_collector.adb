--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Exceptions;
with Podmander.Agent.Host_Command;
with Podmander.Agent.Host_Command.Result_Mapping;
with Podmander.Logging;
with Podmander.Messages.Result_Codes;

package body Podmander.Agent.Status_Collector is

   use Ada.Strings.Unbounded;
   use Podmander.Messages.Status_Responses;
   use type Podmander.Messages.Result_Codes.Result_Code;
   package HC renames Podmander.Agent.Host_Command;
   package RM renames Podmander.Agent.Host_Command.Result_Mapping;
   package RC renames Podmander.Messages.Result_Codes;

   function Collect_Status
      return Status_Response
   is
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
            Error_Message => SU.Null_Unbounded_String);
      else
         Podmander.Logging.Warning
           ("agent", "Status query: podman ps failed");
         declare
            Error_Detail : constant SU.Unbounded_String :=
              (if SU.Length (Result.Error_Output) > 0
               then Result.Error_Output
               else Result.Output);
         begin
            return Status_Response'
              (Code          => Code,
               Containers    => SU.Null_Unbounded_String,
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
            Containers    => SU.Null_Unbounded_String,
            Error_Message => To_Unbounded_String
              (Ada.Exceptions.Exception_Name (E)
               & ": "
               & Ada.Exceptions.Exception_Message (E)));
   end Collect_Status;

end Podmander.Agent.Status_Collector;
