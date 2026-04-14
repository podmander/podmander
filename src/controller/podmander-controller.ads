--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with CZMQ.Pollers;
with CZMQ.Sockets;
with Podmander.Types;

package Podmander.Controller is

   use Podmander.Types;

   --  Agents that miss heartbeats for longer than this are marked
   --  unresponsive (2x) then disconnected (3x). Should match the
   --  expected agent heartbeat interval.
   Default_Agent_Timeout : constant Duration := 30.0;

   type Controller_Config is record
      Bind_Address      : String (1 .. 120) := [others => ' '];
      Bind_Address_Last : Natural := 0;
      Agent_Timeout     : Duration := Default_Agent_Timeout;
   end record;

   procedure Set_Bind_Address
     (Config  : in out Controller_Config;
      Address : String);

   function Get_Bind_Address (Config : Controller_Config) return String;

   package Agent_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Podmander.Types.Agent_Info,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Socket_Access is access CZMQ.Sockets.Socket;

   type Poller_Access is access CZMQ.Pollers.Poller;

   type Controller_Instance is tagged limited record
      Config  : Controller_Config;
      Socket  : Socket_Access := null;
      Poller  : Poller_Access := null;
      Agents  : Agent_Maps.Map;
      Running : Boolean := False;
   end record;

   procedure Initialize
     (Self   : in out Controller_Instance;
      Config : Controller_Config);

   procedure Run_Once (Self : in out Controller_Instance);

   procedure Run (Self : in out Controller_Instance);

   procedure Stop (Self : in out Controller_Instance);

end Podmander.Controller;
