--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.Agent;
with Podmander.CLI;
with Podmander.Logging;

procedure Pod_Agent is
   use Ada.Strings.Unbounded;
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
           ("agent", "Invalid log level '" & Level_Str & "', using Info");
   end;

   declare
      Token : constant String := Podmander.CLI.Get ("token", "");
   begin
      if Token = "" then
         Podmander.CLI.Print_Usage
           ("pod_agent --token <TOKEN> [--connect <ADDR>] "
            & "[--name <NAME>] [--interval <SEC>] [--log-level <LEVEL>]");
         return;
      end if;
   end;

   declare
      Config : constant Podmander.Agent.Agent_Config :=
         (Controller_Address =>
            To_Unbounded_String
              (Podmander.CLI.Get ("connect", "tcp://localhost:5555")),
          Agent_Name =>
            To_Unbounded_String
              (Podmander.CLI.Get ("name", "agent-1")),
          Join_Token =>
            To_Unbounded_String
              (Podmander.CLI.Get ("token", "")),
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
   end;

   Podmander.Logging.Info ("agent", "Agent stopped.");
end Pod_Agent;
