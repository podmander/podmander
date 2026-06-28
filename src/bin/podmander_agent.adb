--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Podmander.Agent;
with Podmander.Agent.Runtime_Config;
with Podmander.Args;
with Podmander.Logging;

procedure Podmander_Agent is
   use Ada.Strings.Unbounded;

   function Config_Argument return String is
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if Arg = "--config" then
               if I = Ada.Command_Line.Argument_Count then
                  return "";
               end if;

               declare
                  Next : constant String := Ada.Command_Line.Argument (I + 1);
               begin
                  if Next'Length > 0 and then Next (1) /= '-' then
                     return Next;
                  end if;

                  return "";
               end;
            elsif Arg'Length >= 9 and then Arg (1 .. 9) = "--config=" then
               if Arg'Length = 9 then
                  return "";
               end if;

               return Arg (10 .. Arg'Last);
            end if;
         end;
      end loop;
      return Podmander.Agent.Runtime_Config.Default_Config_Path;
   end Config_Argument;

   function Config_Explicit return Boolean is
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if Arg = "--config"
              or else (Arg'Length >= 9 and then Arg (1 .. 9) = "--config=")
            then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Config_Explicit;

begin
   declare
      Path     : constant String := Config_Argument;
      Explicit : constant Boolean := Config_Explicit;
   begin
      if Explicit and then Path = "" then
         Podmander.Logging.Critical ("agent", "--config requires a path");
         Ada.Command_Line.Set_Exit_Status (1);
         return;
      end if;

      declare
         Load_Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path          => Path,
              Config_Path_Explicit => Explicit,
              Connect_Override     => Podmander.Args.Get ("connect", ""),
              Token_Override       => Podmander.Args.Get ("token", ""),
              Name_Override        => Podmander.Args.Get ("name", ""),
              Interval_Override    => Podmander.Args.Get ("interval", ""),
              Log_Level_Override   => Podmander.Args.Get ("log-level", ""));
      begin
         if not Load_Result.Success then
            Podmander.Logging.Critical
              ("agent", To_String (Load_Result.Message));
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;

         Podmander.Logging.Set_Level (Load_Result.Value.Log_Level);

         declare
            Agt : Podmander.Agent.Agent_Instance;
         begin
            Agt.Initialize (Load_Result.Value.Config);
            Agt.Run;
         end;
      end;
   end;

   Podmander.Logging.Info ("agent", "Agent stopped.");
end Podmander_Agent;
