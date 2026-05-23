--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Controller;
with Podmander.Controller.Actual_State.Repository;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Message_Handlers;
with Podmander.Controller.Service.Repository;
with Podmander.Database;
with Podmander.Enrollment;
with Podmander.Controller.Message_Handlers;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Deploy_Commands;
with Podmander.Messages.Deploy_Results;
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Result_Codes;
with Podmander.Messages.Status_Responses;
with Podmander.Messages.Registration_Requests;
with Podmander.Messages.Registration_Responses;
with Podmander.Types;

package body Podmander.Controller_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package Svc_Repo renames Podmander.Controller.Service.Repository;
   package AS_Repo renames Podmander.Controller.Actual_State.Repository;

   type Controller_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Controller_Test) return AUnit.Message_String
   is (AUnit.Format ("Controller Message Dispatch"));

   overriding
   procedure Register_Tests (T : in out Controller_Test);

   --  A Message_Handler that records which primitive was invoked and
   --  a copy of the received message. Used to verify Dispatch_To routes
   --  polymorphically to the right typed handler method.
   type Spy_Kind is
     (None,
      Registration_Seen,
      Heartbeat_Seen,
      Deploy_Command_Seen,
      Deploy_Result_Seen,
      Status_Query_Seen,
      Status_Response_Seen);

   package Reg_Reqs renames Podmander.Messages.Registration_Requests;
   package Heartbeats renames Podmander.Messages.Heartbeats;

   type Spy_Handler is limited new Podmander.Messages.Message_Handler
   with record
      Kind              : Spy_Kind := None;
      Last_Registration : Reg_Reqs.Registration_Request;
      Last_Heartbeat    : Heartbeats.Heartbeat_Message;
      Last_Deploy_Cmd   : Podmander.Messages.Deploy_Commands.Deploy_Command;
      Last_Deploy_Res   : Podmander.Messages.Deploy_Results.Deploy_Result;
      Last_Status_Resp  : Podmander.Messages.Status_Responses.Status_Response;
   end record;

   overriding
   procedure Handle_Registration_Request
     (H : in out Spy_Handler;
      M : Podmander.Messages.Registration_Request_Type'Class);

   overriding
   procedure Handle_Heartbeat
     (H : in out Spy_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class);

   overriding
   procedure Handle_Deploy_Command
     (H : in out Spy_Handler;
      M : Podmander.Messages.Deploy_Command_Type'Class);

   overriding
   procedure Handle_Deploy_Result
     (H : in out Spy_Handler; M : Podmander.Messages.Deploy_Result_Type'Class);

   overriding
   procedure Handle_Status_Query
     (H : in out Spy_Handler; M : Podmander.Messages.Status_Query_Type'Class);

   overriding
   procedure Handle_Status_Response
     (H : in out Spy_Handler;
      M : Podmander.Messages.Status_Response_Type'Class);

   overriding
   procedure Handle_Registration_Request
     (H : in out Spy_Handler;
      M : Podmander.Messages.Registration_Request_Type'Class) is
   begin
      H.Kind := Registration_Seen;
      H.Last_Registration :=
        Podmander.Messages.Registration_Requests.Registration_Request (M);
   end Handle_Registration_Request;

   overriding
   procedure Handle_Heartbeat
     (H : in out Spy_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class) is
   begin
      H.Kind := Heartbeat_Seen;
      H.Last_Heartbeat := Podmander.Messages.Heartbeats.Heartbeat_Message (M);
   end Handle_Heartbeat;

   overriding
   procedure Handle_Deploy_Command
     (H : in out Spy_Handler; M : Podmander.Messages.Deploy_Command_Type'Class)
   is
   begin
      H.Kind := Deploy_Command_Seen;
      H.Last_Deploy_Cmd :=
        Podmander.Messages.Deploy_Commands.Deploy_Command (M);
   end Handle_Deploy_Command;

   overriding
   procedure Handle_Deploy_Result
     (H : in out Spy_Handler; M : Podmander.Messages.Deploy_Result_Type'Class)
   is
   begin
      H.Kind := Deploy_Result_Seen;
      H.Last_Deploy_Res := Podmander.Messages.Deploy_Results.Deploy_Result (M);
   end Handle_Deploy_Result;

   overriding
   procedure Handle_Status_Query
     (H : in out Spy_Handler; M : Podmander.Messages.Status_Query_Type'Class)
   is
      pragma Unreferenced (M);
   begin
      H.Kind := Status_Query_Seen;
   end Handle_Status_Query;

   overriding
   procedure Handle_Status_Response
     (H : in out Spy_Handler;
      M : Podmander.Messages.Status_Response_Type'Class) is
   begin
      H.Kind := Status_Response_Seen;
      H.Last_Status_Resp :=
        Podmander.Messages.Status_Responses.Status_Response (M);
   end Handle_Status_Response;

   --  Test: Registration_Request.Dispatch_To routes to Handle_Registration_Request
   procedure Test_Dispatch_Registration_Request
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Requests;
      Req : constant Registration_Request :=
        (Agent_Name        => To_Unbounded_String ("web-1"),
         Enrollment_Secret => To_Unbounded_String ("secret"));
      Spy : Spy_Handler;
   begin
      Req.Dispatch_To (Spy);
      Assert (Spy.Kind = Registration_Seen, "Expected Registration_Seen");
      Assert
        (To_String (Spy.Last_Registration.Agent_Name) = "web-1",
         "Expected agent_name web-1");
   end Test_Dispatch_Registration_Request;

   --  Test: Heartbeat_Message.Dispatch_To routes to Handle_Heartbeat
   procedure Test_Dispatch_Heartbeat
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Heartbeats;
      HB  : constant Heartbeat_Message :=
        (Node_Id   => To_Unbounded_String ("node-1"),
         Timestamp => Ada.Calendar.Clock);
      Spy : Spy_Handler;
   begin
      HB.Dispatch_To (Spy);
      Assert (Spy.Kind = Heartbeat_Seen, "Expected Heartbeat_Seen");
      Assert
        (To_String (Spy.Last_Heartbeat.Node_Id) = "node-1",
         "Expected node_id node-1");
   end Test_Dispatch_Heartbeat;

   --  Test: Polymorphic dispatch through Protocol_Message'Class routes
   --  to the concrete type's handler.
   procedure Test_Dispatch_Polymorphic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Requests;
      Req : constant Registration_Request :=
        (Agent_Name        => To_Unbounded_String ("poly"),
         Enrollment_Secret => To_Unbounded_String ("secret"));
      Msg : constant Podmander.Messages.Protocol_Message'Class := Req;
      Spy : Spy_Handler;
   begin
      Msg.Dispatch_To (Spy);
      Assert
        (Spy.Kind = Registration_Seen,
         "Polymorphic dispatch did not reach Registration handler");
   end Test_Dispatch_Polymorphic;

   --  Test: Registration_Response.Dispatch_To raises Program_Error
   procedure Test_Dispatch_Response_Raises
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Responses;
      Resp : constant Registration_Response :=
        (Node_Id => To_Unbounded_String ("n-1"));
      Spy  : Spy_Handler;
   begin
      Resp.Dispatch_To (Spy);
      Assert (False, "Expected Program_Error from Registration_Response");
   exception
      when Program_Error =>
         null;  --  Expected
   end Test_Dispatch_Response_Raises;

   --  Test: Set_DB_Path / Get_DB_Path round-trip correctly
   procedure Test_Controller_DB_Path_Accessors
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : Podmander.Controller.Controller_Config;
   begin
      Podmander.Controller.Set_DB_Path (Config, "/tmp/test.db");
      Assert
        (Podmander.Controller.Get_DB_Path (Config) = "/tmp/test.db",
         "Set_DB_Path / Get_DB_Path round-trip failed");
   end Test_Controller_DB_Path_Accessors;

   --  Test: Make_Listening_Controller with :memory: DB path returns instance
   procedure Test_Controller_Make_With_DB
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : Podmander.Controller.Controller_Config;
   begin
      Podmander.Controller.Set_DB_Path (Config, ":memory:");
      Podmander.Controller.Set_Bind_Address (Config, "tcp://127.0.0.1:9999");
      declare
         Ctrl : constant Podmander.Controller.Controller_Instance :=
           Podmander.Controller.Make_Listening_Controller (Config);
      begin
         Assert (True, "Make_Listening_Controller with :memory: DB not raise");
      end;
   exception
      when others =>
         Assert (False, "Make_Listening_Controller with :memory: raised");
   end Test_Controller_Make_With_DB;

   --  Test: Agents persist across database connections (simulating restart)
   procedure Test_Startup_Loading (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type Podmander.Types.Agent_State;
      DB_Path : constant String := "/tmp/podmander_test_startup.db";
      Now     : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Info    : constant Podmander.Types.Agent_Info :=
        (Name      => To_Unbounded_String ("persisted-agent"),
         Node_Id   => To_Unbounded_String ("node-001"),
         State     => Podmander.Types.Registered,
         Last_Seen => Now);
      Loaded  : Podmander.Types.Agent_Maps.Map;
      Cur     : Podmander.Types.Agent_Maps.Cursor;
      Element : Podmander.Types.Agent_Info;
   begin
      --  Phase 1: Open DB, register an agent, close (handle auto-finalized)
      declare
         D : Podmander.Database.DB_Handle := Podmander.Database.Open (DB_Path);
      begin
         Podmander.Controller.Agent.Repository.Register (D, Info);
      end;

      --  Phase 2: Open same DB (simulating controller restart), load agents
      declare
         D : Podmander.Database.DB_Handle := Podmander.Database.Open (DB_Path);
      begin
         Loaded := Podmander.Controller.Agent.Repository.Load_All (D);
      end;

      --  Verify the persisted agent was loaded
      Assert (Natural (Loaded.Length) = 1, "Should have 1 agent after reload");

      Cur := Loaded.Find ("persisted-agent");
      Assert
        (Podmander.Types.Agent_Maps.Has_Element (Cur),
         "Persisted agent should be in loaded map");

      Element := Podmander.Types.Agent_Maps.Element (Cur);
      Assert
        (To_String (Element.Name) = "persisted-agent",
         "Agent name should match after reload");
      Assert
        (Element.State = Podmander.Types.Registered,
         "Agent state should be as persisted before restart");

      --  Cleanup
      begin
         Ada.Directories.Delete_File (DB_Path);
      exception
         when Ada.Directories.Name_Error =>
            null;
      end;
      begin
         Ada.Directories.Delete_File (DB_Path & "-wal");
      exception
         when Ada.Directories.Name_Error =>
            null;
      end;
   exception
      when others =>
         begin
            Ada.Directories.Delete_File (DB_Path);
         exception
            when Ada.Directories.Name_Error =>
               null;
         end;
         begin
            Ada.Directories.Delete_File (DB_Path & "-wal");
         exception
            when Ada.Directories.Name_Error =>
               null;
         end;
         raise;
   end Test_Startup_Loading;

   --  Test infrastructure for temp databases
   Test_Counter : Natural := 0;

   function Unique_Temp_Path return String is
   begin
      Test_Counter := Test_Counter + 1;
      return
        "/tmp/podmander_ctrl_test_"
        & Ada.Strings.Fixed.Trim (Test_Counter'Image, Ada.Strings.Both)
        & ".db";
   end Unique_Temp_Path;

   procedure Cleanup_DB (Path : String) is
   begin
      begin
         Ada.Directories.Delete_File (Path);
      exception
         when Ada.Directories.Name_Error =>
            null;
      end;
      begin
         Ada.Directories.Delete_File (Path & "-wal");
      exception
         when Ada.Directories.Name_Error =>
            null;
      end;
      begin
         Ada.Directories.Delete_File (Path & "-shm");
      exception
         when Ada.Directories.Name_Error =>
            null;
      end;
   end Cleanup_DB;

   --  Helpers for Controller_Handler tests that work without a live socket.
   function Make_Ctrl return Podmander.Controller.Controller_Instance is
   begin
      return
         C : Podmander.Controller.Controller_Instance :=
           (Config      => <>,
            DB          => Podmander.Database.Open (":memory:"),
            Certificate => <>,
            Socket      => <>,
            Running     => False,
            Test_Deploy => <>)
      do
         Podmander.Enrollment.Set_Secret (C.Config.Enrollment, "secret");
      end return;
   end Make_Ctrl;

   function Make_Handler
     (Ctrl     : access Podmander.Controller.Controller_Instance;
      Identity : String)
      return Podmander.Controller.Message_Handlers.Controller_Handler is
   begin
      return (Ctrl => Ctrl, Identity => To_Unbounded_String (Identity));
   end Make_Handler;

   --  Test: Pending_Deploy construction and field access
   procedure Test_Pending_Deploy_Construction
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Pending : constant Podmander.Controller.Pending_Deploy :=
        (Service_Name => To_Unbounded_String ("web"),
         Quadlet      =>
           To_Unbounded_String ("[Container]\nContainerImage=nginx"),
         Deployed     => False);
   begin
      Assert
        (To_String (Pending.Service_Name) = "web",
         "Pending_Deploy.Service_Name should be 'web'");
      Assert
        (To_String (Pending.Quadlet) = "[Container]\nContainerImage=nginx",
         "Pending_Deploy.Quadlet should match input");
      Assert
        (not Pending.Deployed,
         "Pending_Deploy.Deployed should be False by default");
   end Test_Pending_Deploy_Construction;

   --  Test: Controller_Instance Test_Deploy field can be set and read
   procedure Test_Controller_Test_Deploy_Field
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
   begin
      Ctrl.Test_Deploy :=
        (Service_Name => To_Unbounded_String ("web"),
         Quadlet      =>
           To_Unbounded_String ("[Container]\nContainerImage=nginx"),
         Deployed     => False);
      Assert
        (To_String (Ctrl.Test_Deploy.Service_Name) = "web",
         "Test_Deploy.Service_Name should be 'web'");
   end Test_Controller_Test_Deploy_Field;

   --  Test: Load_Test_Deploy with a valid TOML file parses, renders, and stores
   procedure Test_Load_Test_Deploy_Valid_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl   : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      Result : constant Boolean :=
        Ctrl.Load_Test_Deploy ("tests/fixtures/valid.toml");
   begin
      Assert (Result, "Load_Test_Deploy should return True for valid file");
      Assert
        (To_String (Ctrl.Test_Deploy.Service_Name) = "web",
         "Test_Deploy.Service_Name should be 'web'");
      Assert
        (not Ctrl.Test_Deploy.Deployed,
         "Test_Deploy.Deployed should be False");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Ctrl.Test_Deploy.Quadlet), "Image=nginx:latest")
         > 0,
         "Quadlet should contain Image=nginx:latest");
   end Test_Load_Test_Deploy_Valid_File;

   --  Test: Load_Test_Deploy with a nonexistent path returns False
   procedure Test_Load_Test_Deploy_Invalid_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl   : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      Result : constant Boolean :=
        Ctrl.Load_Test_Deploy ("/nonexistent/path/file.toml");
   begin
      Assert
        (not Result, "Load_Test_Deploy should return False for invalid file");
      Assert
        (To_String (Ctrl.Test_Deploy.Service_Name) = "",
         "Test_Deploy.Service_Name should be empty after failure");
   end Test_Load_Test_Deploy_Invalid_File;

   --  Test: Handle_Registration_Request adds the agent to the controller's map
   --  when Socket is not yet open (reply Send is guarded by Is_Valid).
   procedure Test_Handle_Registration_Request_Adds_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "node-abc");
      Req  :
        constant Podmander
                   .Messages
                   .Registration_Requests
                   .Registration_Request :=
          (Agent_Name        => To_Unbounded_String ("web-1"),
           Enrollment_Secret => To_Unbounded_String ("secret"));
   begin
      H.Handle_Registration_Request (Req);
      declare
         All_Agents : constant Podmander.Types.Agent_Maps.Map :=
           Podmander.Controller.Agent.Repository.Load_All (Ctrl.DB);
      begin
         Assert (All_Agents.Contains ("web-1"), "Expected agent web-1 in DB");
      end;
   end Test_Handle_Registration_Request_Adds_Agent;

   --  Test: Handle_Heartbeat on a registered agent updates Last_Seen.
   procedure Test_Handle_Heartbeat_Updates_Last_Seen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type Ada.Calendar.Time;
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "node-xyz");
      Past : constant Ada.Calendar.Time := Ada.Calendar.Clock - 60.0;
      Info : constant Podmander.Types.Agent_Info :=
        (Name      => To_Unbounded_String ("web-1"),
         Node_Id   => To_Unbounded_String ("node-xyz"),
         State     => Podmander.Types.Registered,
         Last_Seen => Past);
      HB   : constant Podmander.Messages.Heartbeats.Heartbeat_Message :=
        (Node_Id   => To_Unbounded_String ("node-xyz"),
         Timestamp => Ada.Calendar.Clock);
   begin
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info);
      H.Handle_Heartbeat (HB);
      declare
         Loaded : constant Podmander.Types.Agent_Maps.Map :=
           Podmander.Controller.Agent.Repository.Load_All (Ctrl.DB);
         Cur    : constant Podmander.Types.Agent_Maps.Cursor :=
           Loaded.Find ("web-1");
      begin
         Assert
           (Podmander.Types.Agent_Maps.Has_Element (Cur),
            "Agent should be in DB after heartbeat");
         Assert
           (Podmander.Types.Agent_Maps.Element (Cur).Last_Seen > Past,
            "Last_Seen was not updated");
      end;
   end Test_Handle_Heartbeat_Updates_Last_Seen;

   --  Test: Handle_Heartbeat for unknown agent does not mutate Agents.
   procedure Test_Handle_Heartbeat_Unknown_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "unknown");
      HB   : constant Podmander.Messages.Heartbeats.Heartbeat_Message :=
        (Node_Id   => To_Unbounded_String ("unknown"),
         Timestamp => Ada.Calendar.Clock);
   begin
      H.Handle_Heartbeat (HB);
      declare
         Loaded : constant Podmander.Types.Agent_Maps.Map :=
           Podmander.Controller.Agent.Repository.Load_All (Ctrl.DB);
      begin
         Assert
           (Natural (Loaded.Length) = 0,
            "No agent should be in DB after heartbeat from unknown agent");
      end;
   end Test_Handle_Heartbeat_Unknown_Agent;

   --  Test: Handle_Heartbeat transitions a non-Registered agent back
   --  to Registered.
   procedure Test_Handle_Heartbeat_Reconnect
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type Podmander.Types.Agent_State;
      use type Ada.Calendar.Time;
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "lost-node");
      Info : constant Podmander.Types.Agent_Info :=
        (Name      => To_Unbounded_String ("web-1"),
         Node_Id   => To_Unbounded_String ("lost-node"),
         State     => Podmander.Types.Lost,
         Last_Seen => Ada.Calendar.Clock - 300.0);
      HB   : constant Podmander.Messages.Heartbeats.Heartbeat_Message :=
        (Node_Id   => To_Unbounded_String ("lost-node"),
         Timestamp => Ada.Calendar.Clock);
   begin
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info);
      H.Handle_Heartbeat (HB);
      declare
         Loaded : constant Podmander.Types.Agent_Maps.Map :=
           Podmander.Controller.Agent.Repository.Load_All (Ctrl.DB);
         Cur    : constant Podmander.Types.Agent_Maps.Cursor :=
           Loaded.Find ("web-1");
      begin
         Assert
           (Podmander.Types.Agent_Maps.Has_Element (Cur),
            "Agent should be in DB after heartbeat");
         Assert
           (Podmander.Types.Agent_Maps.Element (Cur).State
            = Podmander.Types.Registered,
            "Expected state to transition to Registered");
      end;
   end Test_Handle_Heartbeat_Reconnect;

   --  Test: Make_Listening_Controller loads an existing secret from DB
   procedure Test_Controller_Startup_Loads_Secret
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Database;
      DB_Path : constant String := Unique_Temp_Path;
      Config  : Podmander.Controller.Controller_Config;
   begin
      --  Pre-seed a registration secret in the DB via a separate connection
      declare
         Pre_Handle : DB_Handle := Open (DB_Path);
      begin
         Set_Setting
           (Pre_Handle,
            "registration_secret",
            "pre_seeded_secret_1234567890123456");
      end;

      Podmander.Controller.Set_DB_Path (Config, DB_Path);
      Podmander.Controller.Set_Bind_Address (Config, "tcp://127.0.0.1:9998");

      declare
         Ctrl : constant Podmander.Controller.Controller_Instance :=
           Podmander.Controller.Make_Listening_Controller (Config);
      begin
         Assert
           (Podmander.Enrollment.Get_Secret (Ctrl.Config.Enrollment)
            = "pre_seeded_secret_1234567890123456",
            "Controller should load pre-seeded registration secret from DB");
      end;
      Cleanup_DB (DB_Path);
   exception
      when others =>
         Cleanup_DB (DB_Path);
         raise;
   end Test_Controller_Startup_Loads_Secret;

   --  Test: Make_Listening_Controller generates a new secret when none exists
   procedure Test_Controller_Startup_Generates_Secret
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Database;
      DB_Path : constant String := Unique_Temp_Path;
      Config  : Podmander.Controller.Controller_Config;
   begin
      Podmander.Controller.Set_DB_Path (Config, DB_Path);
      Podmander.Controller.Set_Bind_Address (Config, "tcp://127.0.0.1:9997");

      declare
         Ctrl          : constant Podmander.Controller.Controller_Instance :=
           Podmander.Controller.Make_Listening_Controller (Config);
         Loaded_Secret : constant String :=
           Podmander.Enrollment.Get_Secret (Ctrl.Config.Enrollment);
      begin
         Assert
           (Loaded_Secret'Length > 0,
            "Controller should have generated a non-empty secret");
      end;

      --  Verify the secret was persisted via a separate connection
      declare
         Post_Handle      : DB_Handle := Open (DB_Path);
         Persisted_Secret : constant String :=
           Get_Setting (Post_Handle, "registration_secret");
      begin
         Assert
           (Persisted_Secret'Length > 0,
            "A registration secret should have been persisted to DB");
      end;
      Cleanup_DB (DB_Path);
   exception
      when others =>
         Cleanup_DB (DB_Path);
         raise;
   end Test_Controller_Startup_Generates_Secret;

   --  Test: Check_Test_Deploy sends deploy when one agent is connected
   procedure Test_Test_Deploy_Trigger_With_One_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      Info : constant Podmander.Types.Agent_Info :=
        (Name      => To_Unbounded_String ("agent-1"),
         Node_Id   => To_Unbounded_String ("node-1"),
         State     => Podmander.Types.Registered,
         Last_Seen => Ada.Calendar.Clock);
   begin
      Ctrl.Test_Deploy :=
        (Service_Name => To_Unbounded_String ("web"),
         Quadlet      =>
           To_Unbounded_String ("[Container]\nContainerImage=nginx"),
         Deployed     => False);
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info);
      Podmander.Controller.Check_Test_Deploy (Ctrl);
      Assert
        (Ctrl.Test_Deploy.Deployed,
         "Check_Test_Deploy should mark Deployed True with one agent");
   end Test_Test_Deploy_Trigger_With_One_Agent;

   --  Test: Check_Test_Deploy waits when no agents are connected
   procedure Test_Test_Deploy_Trigger_With_No_Agents
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
   begin
      Ctrl.Test_Deploy :=
        (Service_Name => To_Unbounded_String ("web"),
         Quadlet      =>
           To_Unbounded_String ("[Container]\nContainerImage=nginx"),
         Deployed     => False);
      Podmander.Controller.Check_Test_Deploy (Ctrl);
      Assert
        (not Ctrl.Test_Deploy.Deployed,
         "Check_Test_Deploy should not mark Deployed True with no agents");
   end Test_Test_Deploy_Trigger_With_No_Agents;

   --  Test: Check_Test_Deploy errors when multiple agents are connected
   procedure Test_Test_Deploy_Trigger_With_Multiple_Agents
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl  : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      Info1 : constant Podmander.Types.Agent_Info :=
        (Name      => To_Unbounded_String ("agent-1"),
         Node_Id   => To_Unbounded_String ("node-1"),
         State     => Podmander.Types.Registered,
         Last_Seen => Ada.Calendar.Clock);
      Info2 : constant Podmander.Types.Agent_Info :=
        (Name      => To_Unbounded_String ("agent-2"),
         Node_Id   => To_Unbounded_String ("node-2"),
         State     => Podmander.Types.Registered,
         Last_Seen => Ada.Calendar.Clock);
   begin
      Ctrl.Test_Deploy :=
        (Service_Name => To_Unbounded_String ("web"),
         Quadlet      =>
           To_Unbounded_String ("[Container]\nContainerImage=nginx"),
         Deployed     => False);
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info1);
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info2);
      Podmander.Controller.Check_Test_Deploy (Ctrl);
      Assert
        (Ctrl.Test_Deploy.Deployed,
         "Check_Test_Deploy should mark Deployed True with multiple agents");
      Assert
        (not Ctrl.Running,
         "Check_Test_Deploy should stop controller with multiple agents");
   end Test_Test_Deploy_Trigger_With_Multiple_Agents;

   --  Test: Check_Test_Deploy waits when only Unresponsive agents exist
   --  (simulates controller restart where agents are loaded from DB but
   --  haven't reconnected yet â they must not receive deploy commands)
   procedure Test_Test_Deploy_Waits_For_Unresponsive_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      Info : constant Podmander.Types.Agent_Info :=
        (Name      => To_Unbounded_String ("agent-1"),
         Node_Id   => To_Unbounded_String ("node-1"),
         State     => Podmander.Types.Unresponsive,
         Last_Seen => Ada.Calendar.Clock);
   begin
      Ctrl.Test_Deploy :=
        (Service_Name => To_Unbounded_String ("web"),
         Quadlet      => To_Unbounded_String ("[Container]\nImage=nginx"),
         Deployed     => False);
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info);
      Podmander.Controller.Check_Test_Deploy (Ctrl);
      Assert
        (not Ctrl.Test_Deploy.Deployed,
         "Check_Test_Deploy should not deploy to Unresponsive agent");
   end Test_Test_Deploy_Waits_For_Unresponsive_Agent;

   --  Test: Check_Test_Deploy does nothing when Service_Name is empty
   procedure Test_Find_State_Mismatches_Detects_Stale
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D          : Podmander.Database.DB_Handle :=
        Podmander.Database.Open (":memory:");
      SV_1       : Podmander.Controller.Service_Version;
      SV_2       : Podmander.Controller.Service_Version;
      AS_Entry   : Podmander.Controller.Actual_State_Entry;
      Mismatches : Podmander.Controller.State_Mismatch_Vectors.Vector;
   begin
      SV_1.Service_Name := To_Unbounded_String ("web");
      SV_1.Version := 1;
      SV_1.Image := To_Unbounded_String ("web:1");
      SV_1.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (D, SV_1);

      SV_2.Service_Name := To_Unbounded_String ("web");
      SV_2.Version := 2;
      SV_2.Image := To_Unbounded_String ("web:2");
      SV_2.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (D, SV_2);

      AS_Entry.Service_Name := To_Unbounded_String ("web");
      AS_Entry.Node_Id := To_Unbounded_String ("node-1");
      AS_Entry.Version := 1;
      AS_Entry.Updated_At := Ada.Calendar.Clock;
      AS_Repo.Upsert (D, AS_Entry);

      Mismatches := Podmander.Controller.Find_State_Mismatches (D);
      Assert
        (Natural (Mismatches.Length) = 1,
         "Should find 1 mismatch when version is stale");
   end Test_Find_State_Mismatches_Detects_Stale;

   procedure Test_Find_State_Mismatches_None_When_Current
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D          : Podmander.Database.DB_Handle :=
        Podmander.Database.Open (":memory:");
      SV         : Podmander.Controller.Service_Version;
      AS_Entry   : Podmander.Controller.Actual_State_Entry;
      Mismatches : Podmander.Controller.State_Mismatch_Vectors.Vector;
   begin
      SV.Service_Name := To_Unbounded_String ("web");
      SV.Version := 1;
      SV.Image := To_Unbounded_String ("web:1");
      SV.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (D, SV);

      AS_Entry.Service_Name := To_Unbounded_String ("web");
      AS_Entry.Node_Id := To_Unbounded_String ("node-1");
      AS_Entry.Version := 1;
      AS_Entry.Updated_At := Ada.Calendar.Clock;
      AS_Repo.Upsert (D, AS_Entry);

      Mismatches := Podmander.Controller.Find_State_Mismatches (D);
      Assert
        (Natural (Mismatches.Length) = 0,
         "Should find 0 mismatches when version is current");
   end Test_Find_State_Mismatches_None_When_Current;

   procedure Test_Find_State_Mismatches_Empty_Actual
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D          : Podmander.Database.DB_Handle :=
        Podmander.Database.Open (":memory:");
      Mismatches : Podmander.Controller.State_Mismatch_Vectors.Vector;
   begin
      Mismatches := Podmander.Controller.Find_State_Mismatches (D);
      Assert
        (Natural (Mismatches.Length) = 0,
         "Should find 0 mismatches when no actual state entries exist");
   end Test_Find_State_Mismatches_Empty_Actual;

   procedure Test_Find_State_Mismatches_Multiple_Services
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D          : Podmander.Database.DB_Handle :=
        Podmander.Database.Open (":memory:");
      SV_1       : Podmander.Controller.Service_Version;
      SV_2       : Podmander.Controller.Service_Version;
      SV_3       : Podmander.Controller.Service_Version;
      AS_1       : Podmander.Controller.Actual_State_Entry;
      AS_2       : Podmander.Controller.Actual_State_Entry;
      Mismatches : Podmander.Controller.State_Mismatch_Vectors.Vector;
   begin
      SV_1.Service_Name := To_Unbounded_String ("web");
      SV_1.Version := 1;
      SV_1.Image := To_Unbounded_String ("web:1");
      SV_1.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (D, SV_1);

      SV_2.Service_Name := To_Unbounded_String ("web");
      SV_2.Version := 2;
      SV_2.Image := To_Unbounded_String ("web:2");
      SV_2.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (D, SV_2);

      SV_3.Service_Name := To_Unbounded_String ("db");
      SV_3.Version := 1;
      SV_3.Image := To_Unbounded_String ("db:1");
      SV_3.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (D, SV_3);

      AS_1.Service_Name := To_Unbounded_String ("web");
      AS_1.Node_Id := To_Unbounded_String ("node-1");
      AS_1.Version := 1;
      AS_1.Updated_At := Ada.Calendar.Clock;
      AS_Repo.Upsert (D, AS_1);

      AS_2.Service_Name := To_Unbounded_String ("web");
      AS_2.Node_Id := To_Unbounded_String ("node-2");
      AS_2.Version := 2;
      AS_2.Updated_At := Ada.Calendar.Clock;
      AS_Repo.Upsert (D, AS_2);

      Mismatches := Podmander.Controller.Find_State_Mismatches (D);
      Assert
        (Natural (Mismatches.Length) = 1,
         "Should find 1 mismatch: only node-1/web is stale");
      if not Mismatches.Is_Empty then
         Assert
           (To_String (Mismatches.First_Element.Service_Name) = "web",
            "Mismatch should be for service 'web'");
         Assert
           (To_String (Mismatches.First_Element.Node_Id) = "node-1",
            "Mismatch should be for node-1");
         Assert
           (Mismatches.First_Element.Desired_Version = 2,
            "Desired version should be 2");
         Assert
           (Mismatches.First_Element.Current_Version = 1,
            "Current version should be 1");
      end if;
   end Test_Find_State_Mismatches_Multiple_Services;

   --  Test: Handle_Deploy_Result logs warning when no Service_Version exists
   --  (defensive: should not crash even if version lookup fails)
   procedure Test_Handle_Deploy_Result_No_Version
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl  : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H     : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "node-1");
      Res   : constant Podmander.Messages.Deploy_Results.Deploy_Result :=
        (Code          => Podmander.Messages.Result_Codes.Ok,
         Service_Name  => To_Unbounded_String ("web"),
         Error_Message => Null_Unbounded_String);
   begin
      --  No Service_Version created for "web" — this should not crash
      H.Handle_Deploy_Result (Res);
      --  If we get here without crashing, the defensive handler worked
      Assert (True, "Handle_Deploy_Result should not crash without version");
   end Test_Handle_Deploy_Result_No_Version;

   --  Test: Check_Test_Deploy does nothing when Service_Name is empty
    procedure Test_Test_Deploy_No_Trigger_When_Empty
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      Info : constant Podmander.Types.Agent_Info :=
        (Name      => To_Unbounded_String ("agent-1"),
         Node_Id   => To_Unbounded_String ("node-1"),
         State     => Podmander.Types.Registered,
         Last_Seen => Ada.Calendar.Clock);
   begin
      --  Leave Test_Deploy at default (empty Service_Name)
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info);
      Podmander.Controller.Check_Test_Deploy (Ctrl);
      Assert
        (not Ctrl.Test_Deploy.Deployed,
         "Check_Test_Deploy should not trigger when Service_Name is empty");
   end Test_Test_Deploy_No_Trigger_When_Empty;

   procedure Test_Handle_Deploy_Result_Updates_Actual_State
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl  : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H     : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "node-1");
      SV    : Podmander.Controller.Service_Version;
      Res   : constant Podmander.Messages.Deploy_Results.Deploy_Result :=
        (Code          => Podmander.Messages.Result_Codes.Ok,
         Service_Name  => To_Unbounded_String ("web"),
         Error_Message => Null_Unbounded_String);
      All_E : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      SV.Service_Name := To_Unbounded_String ("web");
      SV.Version := 1;
      SV.Image := To_Unbounded_String ("web:1");
      SV.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (Ctrl.DB, SV);

      H.Handle_Deploy_Result (Res);

      All_E := Podmander.Controller.Actual_State.Repository.Get_All (Ctrl.DB);
      Assert
        (Natural (All_E.Length) = 1,
         "Should have 1 actual_state entry after deploy result");
      Assert
        (To_String (All_E.First_Element.Service_Name) = "web",
         "Service name should be 'web'");
      Assert
        (To_String (All_E.First_Element.Node_Id) = "node-1",
         "Node ID should be 'node-1'");
      Assert (All_E.First_Element.Version = 1, "Version should be 1");
   end Test_Handle_Deploy_Result_Updates_Actual_State;

   procedure Test_Reconcile_State_No_Op_When_No_Mismatches
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      SV   : Podmander.Controller.Service_Version;
      AS_E : Podmander.Controller.Actual_State_Entry;
   begin
      SV.Service_Name := To_Unbounded_String ("web");
      SV.Version := 1;
      SV.Image := To_Unbounded_String ("web:1");
      SV.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (Ctrl.DB, SV);

      AS_E.Service_Name := To_Unbounded_String ("web");
      AS_E.Node_Id := To_Unbounded_String ("node-1");
      AS_E.Version := 1;
      AS_E.Updated_At := Ada.Calendar.Clock;
      Podmander.Controller.Actual_State.Repository.Upsert (Ctrl.DB, AS_E);

      --  Should not raise (no mismatches = nothing to do)
      Podmander.Controller.Reconcile_State (Ctrl);
      Assert (True, "Reconcile_State completed without error");
   end Test_Reconcile_State_No_Op_When_No_Mismatches;

   procedure Test_Reconcile_State_Skips_Unknown_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      SV_1 : Podmander.Controller.Service_Version;
      SV_2 : Podmander.Controller.Service_Version;
      AS_E : Podmander.Controller.Actual_State_Entry;
   begin
      SV_1.Service_Name := To_Unbounded_String ("web");
      SV_1.Version := 1;
      SV_1.Image := To_Unbounded_String ("web:1");
      SV_1.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (Ctrl.DB, SV_1);

      SV_2.Service_Name := To_Unbounded_String ("web");
      SV_2.Version := 2;
      SV_2.Image := To_Unbounded_String ("web:2");
      SV_2.Created_At := Ada.Calendar.Clock;
      Svc_Repo.Create_Version (Ctrl.DB, SV_2);

      AS_E.Service_Name := To_Unbounded_String ("web");
      AS_E.Node_Id := To_Unbounded_String ("unknown-node");
      AS_E.Version := 1;
      AS_E.Updated_At := Ada.Calendar.Clock;
      Podmander.Controller.Actual_State.Repository.Upsert (Ctrl.DB, AS_E);

      --  Should not raise: agent not in Agents map, so mismatch is skipped
      Podmander.Controller.Reconcile_State (Ctrl);
      Assert (True, "Reconcile_State skipped unknown agent without error");
   end Test_Reconcile_State_Skips_Unknown_Agent;

   overriding
   procedure Register_Tests (T : in out Controller_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Dispatch_Registration_Request'Access,
         "Registration_Request.Dispatch_To routes to Handle_Registration_Request");
      Register_Routine
        (T,
         Test_Dispatch_Heartbeat'Access,
         "Heartbeat_Message.Dispatch_To routes to Handle_Heartbeat");
      Register_Routine
        (T,
         Test_Dispatch_Polymorphic'Access,
         "Polymorphic Dispatch_To routes to concrete handler");
      Register_Routine
        (T,
         Test_Dispatch_Response_Raises'Access,
         "Registration_Response.Dispatch_To raises Program_Error");
      Register_Routine
        (T,
         Test_Handle_Registration_Request_Adds_Agent'Access,
         "Handle_Registration_Request adds agent (no socket)");
      Register_Routine
        (T,
         Test_Handle_Heartbeat_Updates_Last_Seen'Access,
         "Handle_Heartbeat updates Last_Seen for known agent");
      Register_Routine
        (T,
         Test_Handle_Heartbeat_Unknown_Agent'Access,
         "Handle_Heartbeat ignores unknown agent");
      Register_Routine
        (T,
         Test_Handle_Heartbeat_Reconnect'Access,
         "Handle_Heartbeat transitions Lost agent to Registered");
      Register_Routine
        (T,
         Test_Controller_DB_Path_Accessors'Access,
         "Set_DB_Path / Get_DB_Path round-trip");
      Register_Routine
        (T,
         Test_Controller_Make_With_DB'Access,
         "Make_Listening_Controller with memory DB");
      Register_Routine
        (T,
         Test_Startup_Loading'Access,
         "Agents persist across database connections (restart)");
      Register_Routine
        (T,
         Test_Controller_Startup_Loads_Secret'Access,
         "Controller loads pre-seeded registration secret from DB");
      Register_Routine
        (T,
         Test_Controller_Startup_Generates_Secret'Access,
         "Controller generates new secret when none exists");
      Register_Routine
        (T,
         Test_Pending_Deploy_Construction'Access,
         "Pending_Deploy construction and field access");
      Register_Routine
        (T,
         Test_Controller_Test_Deploy_Field'Access,
         "Controller_Instance Test_Deploy field can be set and read");
      Register_Routine
        (T,
         Test_Load_Test_Deploy_Valid_File'Access,
         "Load_Test_Deploy with valid file parses and stores");
      Register_Routine
        (T,
         Test_Load_Test_Deploy_Invalid_File'Access,
         "Load_Test_Deploy with nonexistent file returns False");
      Register_Routine
        (T,
         Test_Test_Deploy_Trigger_With_One_Agent'Access,
         "Check_Test_Deploy sends deploy when one agent is connected");
      Register_Routine
        (T,
         Test_Test_Deploy_Trigger_With_No_Agents'Access,
         "Check_Test_Deploy waits when no agents are connected");
      Register_Routine
        (T,
         Test_Test_Deploy_Trigger_With_Multiple_Agents'Access,
         "Check_Test_Deploy errors when multiple agents are connected");
      Register_Routine
        (T,
         Test_Test_Deploy_Waits_For_Unresponsive_Agent'Access,
         "Check_Test_Deploy waits when only Unresponsive agents exist");
      Register_Routine
        (T,
         Test_Test_Deploy_No_Trigger_When_Empty'Access,
         "Check_Test_Deploy does nothing when Service_Name is empty");
      Register_Routine
        (T,
         Test_Find_State_Mismatches_Detects_Stale'Access,
         "Find_State_Mismatches detects stale version in actual_state");
      Register_Routine
        (T,
         Test_Find_State_Mismatches_None_When_Current'Access,
         "Find_State_Mismatches finds none when version is current");
      Register_Routine
        (T,
         Test_Find_State_Mismatches_Empty_Actual'Access,
         "Find_State_Mismatches returns empty when no actual state");
      Register_Routine
        (T,
         Test_Find_State_Mismatches_Multiple_Services'Access,
         "Find_State_Mismatches detects mismatches across services and nodes");
       Register_Routine
         (T,
          Test_Handle_Deploy_Result_Updates_Actual_State'Access,
          "Handle_Deploy_Result updates actual_state on success");
       Register_Routine
         (T,
          Test_Handle_Deploy_Result_No_Version'Access,
          "Handle_Deploy_Result logs warning when no version exists");
       Register_Routine
         (T,
          Test_Reconcile_State_No_Op_When_No_Mismatches'Access,
         "Reconcile_State is a no-op when there are no mismatches");
      Register_Routine
        (T,
         Test_Reconcile_State_Skips_Unknown_Agent'Access,
         "Reconcile_State skips mismatches for unknown agents");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Controller_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller_Tests;
