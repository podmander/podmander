--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Certificates;
with CZMQ.Sockets;
with Podmander.Types;

package Podmander.Agent is

   type Agent_Config is record
      Controller_Address   : Ada.Strings.Unbounded.Unbounded_String;
      Agent_Name           : Ada.Strings.Unbounded.Unbounded_String;
      Join_Token           : Ada.Strings.Unbounded.Unbounded_String;
      Heartbeat_Interval   : Duration := 30.0;
      Registration_Timeout : Duration := 5.0;
      Max_Backoff          : Duration := 60.0;
   end record;

   --  Certificate and Socket are long-lived fields managed via the
   --  CZMQ Open/Close API. On each reconnect cycle, Close is called
   --  first (idempotent â no-op if already closed), then Open_Dealer
   --  and Generate re-establish the connection. Finalize releases
   --  resources when the agent shuts down.
   type Agent_Instance is tagged limited record
      Config            : Agent_Config;
      State             : Podmander.Types.Connection_State :=
        Podmander.Types.Disconnected;
      Node_Id           : Ada.Strings.Unbounded.Unbounded_String;
      Running           : Boolean := False;
      Backoff           : Duration := 1.0;
      Server_Public_Key : Ada.Strings.Unbounded.Unbounded_String;
      Enrollment_Secret : Ada.Strings.Unbounded.Unbounded_String;
      Certificate       : CZMQ.Certificates.Certificate;
      Sock              : CZMQ.Sockets.Socket;
   end record;

   procedure Initialize (Self : in out Agent_Instance; Config : Agent_Config);

   procedure Run (Self : in out Agent_Instance);

   procedure Stop (Self : in out Agent_Instance);

   function Get_Server_Public_Key (Self : Agent_Instance) return String;

end Podmander.Agent;
