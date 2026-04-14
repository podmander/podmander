--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

with Ada.Strings.Unbounded;
with CZMQ.Sockets;
with Podmander.Types;

package Podmander.Agent is

   type Agent_Config is record
      Controller_Address   : Ada.Strings.Unbounded.Unbounded_String;
      Agent_Name           : Ada.Strings.Unbounded.Unbounded_String;
      Heartbeat_Interval   : Duration := 30.0;
      Registration_Timeout : Duration := 5.0;
      Max_Backoff          : Duration := 60.0;
   end record;

   type Socket_Access is access CZMQ.Sockets.Socket;

   type Agent_Instance is tagged limited record
      Config  : Agent_Config;
      Socket  : Socket_Access := null;
      State   : Podmander.Types.Connection_State :=
        Podmander.Types.Disconnected;
      Node_Id : Ada.Strings.Unbounded.Unbounded_String;
      Running : Boolean := False;
      Backoff : Duration := 1.0;
   end record;

   procedure Initialize
     (Self   : in out Agent_Instance;
      Config : Agent_Config);

   procedure Run_Once (Self : in out Agent_Instance);

   procedure Run (Self : in out Agent_Instance);

   procedure Stop (Self : in out Agent_Instance);

end Podmander.Agent;
