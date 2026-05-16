--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with CZMQ.Certificates;
with CZMQ.Sockets;
with Podmander.Database;
with Podmander.Enrollment;
with Podmander.Types;

package Podmander.Controller is

   use Podmander.Types;

   Default_Agent_Timeout : constant Duration := 30.0;

   type Controller_Config is record
      Bind_Address       : String (1 .. 120) := [others => ' '];
      Bind_Address_Last  : Natural := 0;
      Agent_Timeout      : Duration := Default_Agent_Timeout;
      Enrollment         : Podmander.Enrollment.Enrollment_Config;
      DB_Path            : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String ("");
      --  Path to the SQLite state database.
      --  Empty string means use default: ~/.local/share/podmander/state.db
      --  Uses Unbounded_String (not fixed String like Bind_Address) because
      --  filesystem paths vary widely in length; Bind_Address uses fixed
      --  String because it comes from CLI parsing with known max length.
   end record;

   procedure Set_Bind_Address
     (Config  : in out Controller_Config;
      Address : String);

   function Get_Bind_Address (Config : Controller_Config) return String;

   procedure Set_DB_Path
     (Config : in out Controller_Config;
      Path   : String);

   function Get_DB_Path (Config : Controller_Config) return String;

   package Agent_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Podmander.Types.Agent_Info,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  A deploy that's been queued (via --test-config) but not yet sent.
   --  The controller stores one pending deploy at a time; Test_Deploy on
   --  Controller_Instance holds it until Send_Deploy_Command is called.
   type Pending_Deploy is record
      Service_Name : Ada.Strings.Unbounded.Unbounded_String;
      Quadlet      : Ada.Strings.Unbounded.Unbounded_String;
      Deployed     : Boolean := False;
   end record;

   --  The CURVE certificate and ZeroMQ socket live for the controller's
   --  full lifetime, managed via the CZMQ Open/Close API. Default-initialized
   --  fields are invalid until Make_Listening_Controller calls Generate and
   --  Open_Router. Handler tests rely on that to drive logic without a
   --  live socket; production code obtains a fully-built instance from
   --  Make_Listening_Controller.
   type Controller_Instance is tagged limited record
      Config      : Controller_Config;
      DB          : Database.DB_Handle;
      Certificate : CZMQ.Certificates.Certificate;
      Socket      : CZMQ.Sockets.Socket;
      Agents      : Agent_Maps.Map;
      Running     : Boolean := False;
      Test_Deploy : Pending_Deploy;
   end record;

   --  Build a fully-initialised, listening controller: generate the
   --  CURVE certificate, open the ROUTER socket, enable CURVE server
   --  mode, and bind to Config's Bind_Address. The returned instance
   --  is in the Running state.
   function Make_Listening_Controller
     (Config : Controller_Config) return Controller_Instance;

   procedure Run (Self : in out Controller_Instance);

   procedure Stop (Self : in out Controller_Instance);

   procedure Check_Test_Deploy (Self : in out Controller_Instance);
   --  Check if a pending test-config deploy can be sent to a connected
   --  agent. Sends the deploy command if exactly one agent is connected,
   --  logs an error if multiple agents are connected, and does nothing
   --  if no agents are connected yet.

   function Get_Public_Key (Self : Controller_Instance) return String;

   procedure Generate_Join_Token
      (Self  : in out Controller_Instance;
       Token : out Ada.Strings.Unbounded.Unbounded_String);
   --  Delegates to Podmander.Enrollment.Generate_Join_Token
   --  using this controller's public key and enrollment config.

procedure Send_Deploy_Command
      (Self         : in out Controller_Instance;
       Node_Id      : String;
       Service_Name : String;
       Quadlet      : String);
   --  Encode a Deploy_Command message and send it to the agent identified
   --  by Node_Id. Used by the --test-config CLI path to push a single
   --  quadlet to a single agent. Logs a warning if the socket is not open.

   function Load_Test_Deploy
     (Self : in out Controller_Instance;
      Path : String) return Boolean;
   --  Parse a TOML service config file, render its Quadlet, and store
   --  the result in Test_Deploy. Returns True on success, False on
   --  parse failure (in which case Test_Deploy is unchanged).

end Podmander.Controller;
