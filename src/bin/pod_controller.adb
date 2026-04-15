--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Podmander.CLI;
with Podmander.Controller;

procedure Pod_Controller is
   use Ada.Strings.Unbounded;
   Config : Podmander.Controller.Controller_Config;
   Token  : Unbounded_String;
begin
   Podmander.Controller.Set_Bind_Address
     (Config,
      Podmander.CLI.Get ("bind", "tcp://*:5555"));

   declare
      Ctrl : Podmander.Controller.Controller_Instance;
   begin
      Ctrl.Initialize (Config);
      Ctrl.Generate_Join_Token (Token);
      Ada.Text_IO.Put_Line
        ("Join token: " & To_String (Token));
      Ctrl.Run;
   end;

   Ada.Text_IO.Put_Line ("Controller stopped.");
end Pod_Controller;
