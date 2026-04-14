--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

with Ada.Text_IO;
with Podmander.CLI;
with Podmander.Controller;

procedure Pod_Controller is
   Config : Podmander.Controller.Controller_Config;
begin
   Podmander.Controller.Set_Bind_Address
     (Config,
      Podmander.CLI.Get ("bind", "tcp://*:5555"));

   declare
      Ctrl : Podmander.Controller.Controller_Instance;
   begin
      Ctrl.Initialize (Config);
      Ctrl.Run;
   end;

   Ada.Text_IO.Put_Line ("Controller stopped.");
end Pod_Controller;
