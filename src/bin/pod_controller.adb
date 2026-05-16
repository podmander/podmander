--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.CLI;
with Podmander.Controller;
with Podmander.Logging;

procedure Pod_Controller is
   use Ada.Strings.Unbounded;
   Config : Podmander.Controller.Controller_Config;
   Token  : Unbounded_String;
begin
   declare
      Level_Str : constant String := Podmander.CLI.Get ("log-level", "info");
   begin
      Podmander.Logging.Set_Level
        (Podmander.Logging.Log_Level'Value (Level_Str));
   exception
      when Constraint_Error =>
         Podmander.Logging.Set_Level (Podmander.Logging.Info);
         Podmander.Logging.Warning
           ("controller", "Invalid log level '" & Level_Str & "', using Info");
   end;

   Podmander.Controller.Set_Bind_Address
     (Config, Podmander.CLI.Get ("bind", "tcp://*:5555"));

   declare
      Ctrl : Podmander.Controller.Controller_Instance :=
        Podmander.Controller.Make_Listening_Controller (Config);
   begin
      Ctrl.Generate_Join_Token (Token);
      Podmander.Logging.Info
        ("controller", "Join token: " & To_String (Token));

      --  If --test-config was provided, parse and validate the config,
      --  render the Quadlet, and store it for deployment.
      declare
         Config_Path : constant String :=
           Podmander.CLI.Get ("test-config", "");
      begin
         if Config_Path'Length > 0 then
            if not Ctrl.Load_Test_Deploy (Config_Path) then
               return;
            end if;
         end if;
      end;

      Ctrl.Run;
   end;

   Podmander.Logging.Info ("controller", "Controller stopped.");
end Pod_Controller;
