--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;

package Podmander.Agent.Host_Command is

   package SU renames Ada.Strings.Unbounded;

   type Exit_State is (Error, Exited, Crashed, Terminated);

   type Exit_Status is range 0 .. 255;

   Success : constant Exit_Status := 0;

   type Command_Result (State : Exit_State) is record
      Output       : SU.Unbounded_String;
      Error_Output : SU.Unbounded_String;
      case State is
         when Error =>
            Error_Code : Integer;

         when Exited =>
            Exit_Status : Host_Command.Exit_Status;

         when Crashed | Terminated =>
            Signal : Positive;
      end case;
   end record;

   type Argument_List is array (Positive range <>) of SU.Unbounded_String;

   function "+" (Value : String) return SU.Unbounded_String renames SU.To_Unbounded_String;

   --  Run_Command and Run_Command_Shell block until the spawned process exits
   --  and capture its full stdout/stderr in memory. There is no timeout and
   --  no output bound. Do not call with commands that may run indefinitely or
   --  produce unbounded output (e.g., `podman logs -f`). See issue #19 for the
   --  planned timeout / bounded-capture work.

   function Run_Command (Program : String; Args : Argument_List; Err_To_Out : Boolean := False) return Command_Result
   with Pre => Program'Length > 0;

   function Run_Command_Shell (Command : String; Err_To_Out : Boolean := False) return Command_Result
   with Pre => Command'Length > 0;

end Podmander.Agent.Host_Command;
