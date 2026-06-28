--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Podmander.Agent;
with Podmander.Agent.Runtime_Config;
with Podmander.Args;
with Podmander.Logging;
with Podmander.Runtime_Config_Helpers;

procedure Podmander_Agent is
   use Ada.Strings.Unbounded;
begin
   declare
      Explicit : Boolean;
      Path     : constant String :=
        Podmander.Runtime_Config_Helpers.Config_Path_From_Arguments
          (Podmander.Agent.Runtime_Config.Default_Config_Path, Explicit);
   begin
      if Explicit and then Path = "" then
         Podmander.Logging.Critical ("agent", "--config requires a path");
         Ada.Command_Line.Set_Exit_Status (1);
         return;
      end if;

      declare
         Overrides   :
           constant Podmander.Agent.Runtime_Config.Config_Overrides :=
             (Connect   =>
                To_Unbounded_String (Podmander.Args.Get ("connect", "")),
              Token     =>
                To_Unbounded_String (Podmander.Args.Get ("token", "")),
              Name      =>
                To_Unbounded_String (Podmander.Args.Get ("name", "")),
              Interval  =>
                To_Unbounded_String (Podmander.Args.Get ("interval", "")),
              Log_Level =>
                To_Unbounded_String (Podmander.Args.Get ("log-level", "")));
         Load_Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path          => Path,
              Config_Path_Explicit => Explicit,
              Overrides            => Overrides);
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
