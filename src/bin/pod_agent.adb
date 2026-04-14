--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Podmander.Agent;
with Podmander.CLI;

procedure Pod_Agent is
   use Ada.Strings.Unbounded;

   Config : constant Podmander.Agent.Agent_Config :=
     (Controller_Address =>
        To_Unbounded_String
          (Podmander.CLI.Get ("connect", "tcp://localhost:5555")),
      Agent_Name =>
        To_Unbounded_String
          (Podmander.CLI.Get ("name", "agent-1")),
      Heartbeat_Interval =>
        Podmander.CLI.Get_Duration ("interval", 30.0),
      Registration_Timeout => 5.0,
      Max_Backoff          => 60.0);
begin
   declare
      Agt : Podmander.Agent.Agent_Instance;
   begin
      Agt.Initialize (Config);
      Agt.Run;
   end;

   Ada.Text_IO.Put_Line ("Agent stopped.");
end Pod_Agent;
