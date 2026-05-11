--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Agent.Connection;
with Podmander.Enrollment;
with Podmander.Logging;
with CZMQ.Signals;

package body Podmander.Agent is

   use Ada.Strings.Unbounded;

   procedure Initialize
     (Self   : in out Agent_Instance;
      Config : Agent_Config) is
   begin
      Self.Config := Config;
      Self.Running := True;

      --  Parse the join token once at startup so a malformed token surfaces
      --  before the run loop, and so Get_Server_Public_Key serves the
      --  cached value rather than re-parsing on every call. Agents started
      --  without a token (default config) defer the failure to the first
      --  connection cycle to preserve the existing pre-cache behaviour.
      if Config.Join_Token /= Null_Unbounded_String then
         declare
            Parsed : constant Podmander.Enrollment.Parsed_Token :=
              Podmander.Enrollment.Parse_Join_Token
                (To_String (Config.Join_Token));
         begin
            Self.Server_Public_Key := Parsed.Public_Key;
            Self.Enrollment_Secret := Parsed.Secret;
         end;
      end if;

      Podmander.Logging.Info
        ("agent", "Agent """ & To_String (Config.Agent_Name)
         & """ starting, controller at "
         & To_String (Config.Controller_Address));
   end Initialize;

   procedure Run (Self : in out Agent_Instance) is
   begin
      while Self.Running
        and then not CZMQ.Signals.Is_Interrupted
      loop
         Connection.Run_Cycle (Self);
      end loop;
   end Run;

   procedure Stop (Self : in out Agent_Instance) is
   begin
      Self.Running := False;
   end Stop;

   function Get_Server_Public_Key
     (Self : Agent_Instance) return String is
   begin
      return To_String (Self.Server_Public_Key);
   end Get_Server_Public_Key;

end Podmander.Agent;
