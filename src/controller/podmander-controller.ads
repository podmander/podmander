--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with CZMQ.Certificates;
with CZMQ.Pollers;
with CZMQ.Sockets;
with Podmander.Types;

package Podmander.Controller is

   use Podmander.Types;

   Default_Agent_Timeout : constant Duration := 30.0;

   type Controller_Config is record
      Bind_Address       : String (1 .. 120) := [others => ' '];
      Bind_Address_Last  : Natural := 0;
      Agent_Timeout      : Duration := Default_Agent_Timeout;
      Enrollment_Secret  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   procedure Set_Bind_Address
     (Config  : in out Controller_Config;
      Address : String);

   function Get_Bind_Address (Config : Controller_Config) return String;

   Token_Prefix : constant String := "PTKN-";

   procedure Set_Enrollment_Secret
     (Config : in out Controller_Config;
      Secret : String);

   function Get_Enrollment_Secret (Config : Controller_Config) return String;

   package Agent_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Podmander.Types.Agent_Info,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Certificate_Access is access CZMQ.Certificates.Certificate;

   type Socket_Access is access CZMQ.Sockets.Socket;

   type Poller_Access is access CZMQ.Pollers.Poller;

   type Controller_Instance is tagged limited record
      Config      : Controller_Config;
      Certificate : Certificate_Access := null;
      Socket      : Socket_Access := null;
      Poller      : Poller_Access := null;
      Agents      : Agent_Maps.Map;
      Running     : Boolean := False;
   end record;

   procedure Initialize
     (Self   : in out Controller_Instance;
      Config : Controller_Config);

   procedure Run_Once (Self : in out Controller_Instance);

   procedure Run (Self : in out Controller_Instance);

   procedure Stop (Self : in out Controller_Instance);

   function Get_Public_Key (Self : Controller_Instance) return String;

   procedure Generate_Join_Token
     (Self  : in out Controller_Instance;
      Token : out Ada.Strings.Unbounded.Unbounded_String);

end Podmander.Controller;
