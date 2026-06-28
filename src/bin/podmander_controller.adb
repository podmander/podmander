--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Podmander.Args;
with Podmander.Controller;
with Podmander.Controller.Runtime_Config;
with Podmander.Logging;
with Podmander.Runtime_Config_Helpers;

procedure Podmander_Controller is
   use Ada.Strings.Unbounded;
   Token : Unbounded_String;
begin
   declare
      Explicit : Boolean;
      Path     : constant String :=
        Podmander.Runtime_Config_Helpers.Config_Path_From_Arguments
          (Podmander.Controller.Runtime_Config.Default_Config_Path, Explicit);
   begin
      if Explicit and then Path = "" then
         Podmander.Logging.Critical ("controller", "--config requires a path");
         Ada.Command_Line.Set_Exit_Status (1);
         return;
      end if;

      declare
         Overrides   :
           constant Podmander.Controller.Runtime_Config.Config_Overrides :=
             (Bind      =>
                To_Unbounded_String (Podmander.Args.Get ("bind", "")),
              Log_Level =>
                To_Unbounded_String (Podmander.Args.Get ("log-level", "")));
         Load_Result :
           constant Podmander.Controller.Runtime_Config.Load_Result :=
             Podmander.Controller.Runtime_Config.Load
               (Config_Path          => Path,
                Config_Path_Explicit => Explicit,
                Overrides            => Overrides);
      begin
         if not Load_Result.Success then
            Podmander.Logging.Critical
              ("controller", To_String (Load_Result.Message));
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;

         Podmander.Logging.Set_Level (Load_Result.Value.Log_Level);

         declare
            Ctrl : Podmander.Controller.Controller_Instance :=
              Podmander.Controller.Make_Listening_Controller
                (Load_Result.Value.Config);
         begin
            Ctrl.Generate_Join_Token (Token);
            Podmander.Logging.Info
              ("controller", "Join token: " & To_String (Token));

            Ctrl.Run;
         end;
      end;
   end;

   Podmander.Logging.Info ("controller", "Controller stopped.");
end Podmander_Controller;
