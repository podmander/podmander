--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with CZMQ.Certificates;
with CZMQ.Sockets;
with Podmander.Config;
with Podmander.Database;
with Podmander.Enrollment;
with Podmander.Types;

package Podmander.Controller is

   use Podmander.Config;

   --  Domain-specific ID types. Derived from Positive so the compiler
   --  catches accidental mixing of service IDs, version numbers, and
   --  generic integers.

   type Service_Id_Type is new Positive;
   --  Row identifier in the services table. Distinct from Integer so
   --  a catalog-entry ID or version number cannot be passed by mistake.

   type Service_Version_Type is new Positive;
   --  Semantic version number for a service deployment (always >= 1).
   --  Used for both Service_Version.Version and catalog Target_Version.

   type Node_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Node_Id : Podmander.Types.Node_Id_Type;

         when False =>
            null;
      end case;
   end record;
   --  Scheduling strategy return type: Present => True carries the selected
   --  node; Present => False means no eligible node was found.

   type Version_Option (Present : Boolean := False) is record
      case Present is
         when True =>
            Version : Service_Version_Type;

         when False =>
            null;
      end case;
   end record;
   --  Option type for Current_Version in Service_Catalog_Entry.
   --  Present => False means the service has not yet been deployed.

   -- State tracking types

   type Service_Version is record
      Id            : Integer;
      Service_Id    : Service_Id_Type;
      Version       : Service_Version_Type;
      Image         : Ada.Strings.Unbounded.Unbounded_String;
      Env           : Env_Array (1 .. MAX_ENV_ENTRIES);
      Env_Count     : Natural := 0;
      Ports         : Port_Array (1 .. MAX_PORTS_ENTRIES);
      Ports_Count   : Natural := 0;
      Volumes       : Volume_Array (1 .. MAX_VOLUMES_ENTRIES);
      Volumes_Count : Natural := 0;
      Description   : Ada.Strings.Unbounded.Unbounded_String;
      Wanted_By     : Ada.Strings.Unbounded.Unbounded_String;
      Created_At    : Ada.Calendar.Time;
   end record;

   type Service_Node_Key is record
      Service_Name  : Ada.Strings.Unbounded.Unbounded_String;
      Connection_Id : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Catalog_Entry_State is
     (Pending,      -- needs deployment
      In_Progress,  -- deploy command sent, awaiting result
      Failed,       -- deploy failed, needs retrigger
      Deployed);    -- current_version == target_version

   type Service_Catalog_Entry is record
      Id              : Integer;
      Service_Id      : Service_Id_Type;
      Node_Id         : Node_Option;
      Current_Version : Version_Option;
      Target_Version  : Service_Version_Type;
      State           : Catalog_Entry_State := Pending;
      Updated_At      : Ada.Calendar.Time;
   end record;

   package Catalog_Entry_Vectors is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Service_Catalog_Entry);

   Default_Agent_Timeout : constant Duration := 30.0;

   type Controller_Config is record
      Bind_Address      : String (1 .. 120) := [others => ' '];
      Bind_Address_Last : Natural := 0;
      Agent_Timeout     : Duration := Default_Agent_Timeout;
      Enrollment        : Podmander.Enrollment.Enrollment_Config;
      DB_Path           : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String ("");
      -- Path to the SQLite state database.
      -- Empty string means use default: ~/.local/share/podmander/state.db
      -- Uses Unbounded_String (not fixed String like Bind_Address) because
      -- filesystem paths vary widely in length; Bind_Address uses fixed
      -- String because it comes from CLI parsing with known max length.
   end record;

   procedure Set_Bind_Address
     (Config : in out Controller_Config; Address : String);

   function Get_Bind_Address (Config : Controller_Config) return String;

   procedure Set_DB_Path (Config : in out Controller_Config; Path : String);

   function Get_DB_Path (Config : Controller_Config) return String;

   -- The CURVE certificate and ZeroMQ socket live for the controller's
   -- full lifetime, managed via the CZMQ Open/Close API. Default-initialized
   -- fields are invalid until Make_Listening_Controller calls Generate and
   -- Open_Router. Handler tests rely on that to drive logic without a
   -- live socket; production code obtains a fully-built instance from
   -- Make_Listening_Controller.
   type Controller_Instance is tagged limited record
      Config      : Controller_Config;
      DB          : Database.DB_Handle;
      Certificate : CZMQ.Certificates.Certificate;
      Socket      : CZMQ.Sockets.Socket;
      Running     : Boolean := False;
   end record;

   -- Build a fully-initialised, listening controller: generate the
   -- CURVE certificate, open the ROUTER socket, enable CURVE server
   -- mode, and bind to Config's Bind_Address. The returned instance
   -- is in the Running state.
   function Make_Listening_Controller
     (Config : Controller_Config) return Controller_Instance;

   procedure Run (Self : in out Controller_Instance);

   procedure Stop (Self : in out Controller_Instance);

   function Get_Public_Key (Self : Controller_Instance) return String;

   procedure Generate_Join_Token
     (Self  : in out Controller_Instance;
      Token : out Ada.Strings.Unbounded.Unbounded_String);
   -- Delegates to Podmander.Enrollment.Generate_Join_Token
   -- using this controller's public key and enrollment config.

end Podmander.Controller;
