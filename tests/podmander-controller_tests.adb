--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Controller;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Message_Handlers;
with Podmander.Controller.Node.Repository;
with Podmander.Controller.Service;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Stack_Submission;
with Podmander.Database;
with Podmander.Enrollment;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Deployment_Commands;
with Podmander.Messages.Deployment_Results;
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Result_Codes;
with Podmander.Messages.Status_Responses;
with Podmander.Messages.Registration_Requests;
with Podmander.Messages.Registration_Responses;
with Podmander.Messages.Stack_Submissions;
with Podmander.Messages.Stack_Submission_Results;
with Podmander.Types;

package body Podmander.Controller_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Types;

    package Svc_Repo renames Podmander.Controller.Service.Repository;
    package Node_Repo renames Podmander.Controller.Node.Repository;

   type Controller_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Controller_Test) return AUnit.Message_String
   is (AUnit.Format ("Controller Message Dispatch"));

   overriding
   procedure Register_Tests (T : in out Controller_Test);

   -- A Message_Handler that records which primitive was invoked and
   -- a copy of the received message. Used to verify Dispatch_To routes
   -- polymorphically to the right typed handler method.
   type Spy_Kind is
     (None,
      Registration_Seen,
      Heartbeat_Seen,
      Deployment_Command_Seen,
      Deployment_Result_Seen,
      Status_Query_Seen,
      Status_Response_Seen,
      Stack_Submission_Seen,
      Stack_Submission_Result_Seen);

   package Reg_Reqs renames Podmander.Messages.Registration_Requests;
   package Heartbeats renames Podmander.Messages.Heartbeats;

   type Spy_Handler is limited new Podmander.Messages.Message_Handler with record
      Kind              : Spy_Kind := None;
      Last_Registration : Reg_Reqs.Registration_Request;
      Last_Heartbeat    : Heartbeats.Heartbeat_Message;
      Last_Deploy_Cmd   : Podmander.Messages.Deployment_Commands.Deployment_Command;
      Last_Deploy_Res   : Podmander.Messages.Deployment_Results.Deployment_Result;
      Last_Status_Resp  : Podmander.Messages.Status_Responses.Status_Response;
      Last_Stack_Submission        : Podmander.Messages.Stack_Submissions.Stack_Submission;
      Last_Stack_Submission_Result : Podmander.Messages.Stack_Submission_Results.Stack_Submission_Result;
   end record;

   overriding
   procedure Handle_Registration_Request
     (H : in out Spy_Handler; M : Podmander.Messages.Registration_Request_Type'Class);

   overriding
   procedure Handle_Heartbeat (H : in out Spy_Handler; M : Podmander.Messages.Heartbeat_Message_Type'Class);

   overriding
   procedure Handle_Deployment_Command (H : in out Spy_Handler; M : Podmander.Messages.Deployment_Command_Type'Class);

   overriding
   procedure Handle_Deployment_Result (H : in out Spy_Handler; M : Podmander.Messages.Deployment_Result_Type'Class);

   overriding
   procedure Handle_Status_Query (H : in out Spy_Handler; M : Podmander.Messages.Status_Query_Type'Class);

   overriding
   procedure Handle_Status_Response (H : in out Spy_Handler; M : Podmander.Messages.Status_Response_Type'Class);

   overriding
   procedure Handle_Stack_Submission (H : in out Spy_Handler; M : Podmander.Messages.Stack_Submission_Type'Class);

   overriding
   procedure Handle_Stack_Submission_Result
     (H : in out Spy_Handler; M : Podmander.Messages.Stack_Submission_Result_Type'Class);

   overriding
   procedure Handle_Registration_Request
     (H : in out Spy_Handler; M : Podmander.Messages.Registration_Request_Type'Class) is
   begin
      H.Kind := Registration_Seen;
      H.Last_Registration := Podmander.Messages.Registration_Requests.Registration_Request (M);
   end Handle_Registration_Request;

   overriding
   procedure Handle_Heartbeat (H : in out Spy_Handler; M : Podmander.Messages.Heartbeat_Message_Type'Class) is
   begin
      H.Kind := Heartbeat_Seen;
      H.Last_Heartbeat := Podmander.Messages.Heartbeats.Heartbeat_Message (M);
   end Handle_Heartbeat;

   overriding
   procedure Handle_Deployment_Command (H : in out Spy_Handler; M : Podmander.Messages.Deployment_Command_Type'Class) is
   begin
      H.Kind := Deployment_Command_Seen;
      H.Last_Deploy_Cmd := Podmander.Messages.Deployment_Commands.Deployment_Command (M);
   end Handle_Deployment_Command;

   overriding
   procedure Handle_Deployment_Result (H : in out Spy_Handler; M : Podmander.Messages.Deployment_Result_Type'Class) is
   begin
      H.Kind := Deployment_Result_Seen;
      H.Last_Deploy_Res := Podmander.Messages.Deployment_Results.Deployment_Result (M);
   end Handle_Deployment_Result;

   overriding
   procedure Handle_Status_Query (H : in out Spy_Handler; M : Podmander.Messages.Status_Query_Type'Class) is
      pragma Unreferenced (M);
   begin
      H.Kind := Status_Query_Seen;
   end Handle_Status_Query;

   overriding
   procedure Handle_Status_Response (H : in out Spy_Handler; M : Podmander.Messages.Status_Response_Type'Class) is
   begin
      H.Kind := Status_Response_Seen;
      H.Last_Status_Resp := Podmander.Messages.Status_Responses.Status_Response (M);
   end Handle_Status_Response;

   overriding
   procedure Handle_Stack_Submission
     (H : in out Spy_Handler; M : Podmander.Messages.Stack_Submission_Type'Class) is
   begin
      H.Kind := Stack_Submission_Seen;
      H.Last_Stack_Submission := Podmander.Messages.Stack_Submissions.Stack_Submission (M);
   end Handle_Stack_Submission;

   overriding
   procedure Handle_Stack_Submission_Result
     (H : in out Spy_Handler; M : Podmander.Messages.Stack_Submission_Result_Type'Class) is
   begin
      H.Kind := Stack_Submission_Result_Seen;
      H.Last_Stack_Submission_Result :=
        Podmander.Messages.Stack_Submission_Results.Stack_Submission_Result (M);
   end Handle_Stack_Submission_Result;

   -- Test: Registration_Request.Dispatch_To routes to Handle_Registration_Request
   procedure Test_Dispatch_Registration_Request (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Requests;
      Req : constant Registration_Request :=
        (Agent_Name => To_Unbounded_String ("web-1"), Enrollment_Secret => To_Unbounded_String ("secret"));
      Spy : Spy_Handler;
   begin
      Req.Dispatch_To (Spy);
      Assert (Spy.Kind = Registration_Seen, "Expected Registration_Seen");
      Assert (To_String (Spy.Last_Registration.Agent_Name) = "web-1", "Expected agent_name web-1");
   end Test_Dispatch_Registration_Request;

   -- Test: Heartbeat_Message.Dispatch_To routes to Handle_Heartbeat
   procedure Test_Dispatch_Heartbeat (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Heartbeats;
      HB  : constant Heartbeat_Message := (Connection_Id => To_Unbounded_String ("node-1"), Timestamp => Ada.Calendar.Clock);
      Spy : Spy_Handler;
   begin
      HB.Dispatch_To (Spy);
      Assert (Spy.Kind = Heartbeat_Seen, "Expected Heartbeat_Seen");
      Assert (To_String (Spy.Last_Heartbeat.Connection_Id) = "node-1", "Expected connection_id node-1");
   end Test_Dispatch_Heartbeat;

   -- Test: Polymorphic dispatch through Protocol_Message'Class routes
   -- to the concrete type's handler.
   procedure Test_Dispatch_Polymorphic (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Requests;
      Req : constant Registration_Request :=
        (Agent_Name => To_Unbounded_String ("poly"), Enrollment_Secret => To_Unbounded_String ("secret"));
      Msg : constant Podmander.Messages.Protocol_Message'Class := Req;
      Spy : Spy_Handler;
   begin
      Msg.Dispatch_To (Spy);
      Assert (Spy.Kind = Registration_Seen, "Polymorphic dispatch did not reach Registration handler");
   end Test_Dispatch_Polymorphic;

   -- Test: Registration_Response.Dispatch_To raises Program_Error
   procedure Test_Dispatch_Response_Raises (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Responses;
      Resp : constant Registration_Response := (Connection_Id => To_Unbounded_String ("n-1"));
      Spy  : Spy_Handler;
   begin
      Resp.Dispatch_To (Spy);
      Assert (False, "Expected Program_Error from Registration_Response");
   exception
      when Program_Error =>
         null;  --  Expected
   end Test_Dispatch_Response_Raises;

   -- Test: Set_DB_Path / Get_DB_Path round-trip correctly
   procedure Test_Controller_DB_Path_Accessors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : Podmander.Controller.Controller_Config;
   begin
      Podmander.Controller.Set_DB_Path (Config, "/tmp/test.db");
      Assert
        (Podmander.Controller.Get_DB_Path (Config) = "/tmp/test.db", "Set_DB_Path / Get_DB_Path round-trip failed");
   end Test_Controller_DB_Path_Accessors;

   -- Test: Make_Listening_Controller with :memory: DB path returns instance
   procedure Test_Controller_Make_With_DB (T : in out AUnit.Test_Cases.Test_Case'Class) is
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

   -- Test: Agents persist across database connections (simulating restart)
    procedure Test_Startup_Loading (T : in out AUnit.Test_Cases.Test_Case'Class) is
       pragma Unreferenced (T);
       use type Podmander.Types.Agent_State;
       DB_Path : constant String := "/tmp/podmander_test_startup.db";
       Now     : constant Ada.Calendar.Time := Ada.Calendar.Clock;
       Loaded  : Podmander.Types.Agent_Maps.Map;
       Cur     : Podmander.Types.Agent_Maps.Cursor;
       Element : Podmander.Types.Agent_Info;
    begin
       -- Phase 1: Open DB, register an agent, close (handle auto-finalized)
       declare
          D       : Podmander.Database.DB_Handle := Podmander.Database.Open (DB_Path);
          Node_Id : constant Node_Id_Type := Node_Repo.Create_Or_Get (D, "persisted-agent");
       begin
          Podmander.Controller.Agent.Repository.Register
            (D,
             (Id            => 0,
              Name          => To_Unbounded_String ("persisted-agent"),
              Connection_Id => To_Unbounded_String ("node-001"),
              State         => Podmander.Types.Registered,
              Last_Seen     => Now,
              Node_Id       => Node_Id));
       end;

      -- Phase 2: Open same DB (simulating controller restart), load agents
      declare
         D : Podmander.Database.DB_Handle := Podmander.Database.Open (DB_Path);
      begin
         Loaded := Podmander.Controller.Agent.Repository.Load_All (D);
      end;

      -- Verify the persisted agent was loaded
      Assert (Natural (Loaded.Length) = 1, "Should have 1 agent after reload");

      Cur := Loaded.Find ("persisted-agent");
      Assert (Podmander.Types.Agent_Maps.Has_Element (Cur), "Persisted agent should be in loaded map");

      Element := Podmander.Types.Agent_Maps.Element (Cur);
      Assert (To_String (Element.Name) = "persisted-agent", "Agent name should match after reload");
      Assert (Element.State = Podmander.Types.Registered, "Agent state should be as persisted before restart");

      -- Cleanup
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

   -- Test infrastructure for temp databases
   Test_Counter : Natural := 0;

   function Unique_Temp_Path return String is
   begin
      Test_Counter := Test_Counter + 1;
      return "/tmp/podmander_ctrl_test_" & Ada.Strings.Fixed.Trim (Test_Counter'Image, Ada.Strings.Both) & ".db";
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

   -- Helpers for Controller_Handler tests that work without a live socket.
   function Make_Ctrl return Podmander.Controller.Controller_Instance is
   begin
      return
         C : Podmander.Controller.Controller_Instance :=
           (Config => <>, DB => Podmander.Database.Open (":memory:"), Certificate => <>, Socket => <>, Running => False)
      do
         Podmander.Enrollment.Set_Secret (C.Config.Enrollment, "secret");
      end return;
   end Make_Ctrl;

   function Make_Handler
     (Ctrl : access Podmander.Controller.Controller_Instance; Identity : String)
      return Podmander.Controller.Message_Handlers.Controller_Handler is
   begin
      return (Ctrl => Ctrl, Identity => To_Unbounded_String (Identity));
   end Make_Handler;

   -- Test: Handle_Registration_Request adds the agent to the controller's map
   -- when Socket is not yet open (reply Send is guarded by Is_Valid).
   procedure Test_Handle_Registration_Request_Adds_Agent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler := Make_Handler (Ctrl'Access, "node-abc");
      Req  : constant Podmander.Messages.Registration_Requests.Registration_Request :=
        (Agent_Name => To_Unbounded_String ("web-1"), Enrollment_Secret => To_Unbounded_String ("secret"));
   begin
      H.Handle_Registration_Request (Req);
      declare
         All_Agents : constant Podmander.Types.Agent_Maps.Map :=
           Podmander.Controller.Agent.Repository.Load_All (Ctrl.DB);
      begin
         Assert (All_Agents.Contains ("web-1"), "Expected agent web-1 in DB");
      end;
   end Test_Handle_Registration_Request_Adds_Agent;

   -- Test: Handle_Heartbeat on a registered agent updates Last_Seen.
    procedure Test_Handle_Heartbeat_Updates_Last_Seen (T : in out AUnit.Test_Cases.Test_Case'Class) is
       pragma Unreferenced (T);
       use type Ada.Calendar.Time;
       Ctrl    : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
       H       : Podmander.Controller.Message_Handlers.Controller_Handler := Make_Handler (Ctrl'Access, "node-xyz");
       Past    : constant Ada.Calendar.Time := Ada.Calendar.Clock - 60.0;
       Node_Id : constant Node_Id_Type := Node_Repo.Create_Or_Get (Ctrl.DB, "web-1");
       Info    : constant Podmander.Types.Agent_Info :=
          (Id            => 0,
           Name          => To_Unbounded_String ("web-1"),
           Connection_Id => To_Unbounded_String ("node-xyz"),
           State         => Podmander.Types.Registered,
           Last_Seen     => Past,
           Node_Id       => Node_Id);
       HB   : constant Podmander.Messages.Heartbeats.Heartbeat_Message :=
         (Connection_Id => To_Unbounded_String ("node-xyz"), Timestamp => Ada.Calendar.Clock);
    begin
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info);
      H.Handle_Heartbeat (HB);
      declare
         Loaded : constant Podmander.Types.Agent_Maps.Map := Podmander.Controller.Agent.Repository.Load_All (Ctrl.DB);
         Cur    : constant Podmander.Types.Agent_Maps.Cursor := Loaded.Find ("web-1");
      begin
         Assert (Podmander.Types.Agent_Maps.Has_Element (Cur), "Agent should be in DB after heartbeat");
         Assert (Podmander.Types.Agent_Maps.Element (Cur).Last_Seen > Past, "Last_Seen was not updated");
      end;
   end Test_Handle_Heartbeat_Updates_Last_Seen;

   -- Test: Handle_Heartbeat for unknown agent does not mutate Agents.
   procedure Test_Handle_Heartbeat_Unknown_Agent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler := Make_Handler (Ctrl'Access, "unknown");
      HB   : constant Podmander.Messages.Heartbeats.Heartbeat_Message :=
        (Connection_Id => To_Unbounded_String ("unknown"), Timestamp => Ada.Calendar.Clock);
   begin
      H.Handle_Heartbeat (HB);
      declare
         Loaded : constant Podmander.Types.Agent_Maps.Map := Podmander.Controller.Agent.Repository.Load_All (Ctrl.DB);
      begin
         Assert (Natural (Loaded.Length) = 0, "No agent should be in DB after heartbeat from unknown agent");
      end;
   end Test_Handle_Heartbeat_Unknown_Agent;

   -- Test: Handle_Heartbeat transitions a non-Registered agent back
   -- to Registered.
    procedure Test_Handle_Heartbeat_Reconnect (T : in out AUnit.Test_Cases.Test_Case'Class) is
       pragma Unreferenced (T);
       use type Podmander.Types.Agent_State;
       use type Ada.Calendar.Time;
       Ctrl    : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
       H       : Podmander.Controller.Message_Handlers.Controller_Handler := Make_Handler (Ctrl'Access, "lost-node");
       Node_Id : constant Node_Id_Type := Node_Repo.Create_Or_Get (Ctrl.DB, "web-1");
       Info    : constant Podmander.Types.Agent_Info :=
          (Id            => 0,
           Name          => To_Unbounded_String ("web-1"),
           Connection_Id => To_Unbounded_String ("lost-node"),
           State         => Podmander.Types.Lost,
           Last_Seen     => Ada.Calendar.Clock - 300.0,
           Node_Id       => Node_Id);
       HB   : constant Podmander.Messages.Heartbeats.Heartbeat_Message :=
         (Connection_Id => To_Unbounded_String ("lost-node"), Timestamp => Ada.Calendar.Clock);
    begin
      Podmander.Controller.Agent.Repository.Register (Ctrl.DB, Info);
      H.Handle_Heartbeat (HB);
      declare
         Loaded : constant Podmander.Types.Agent_Maps.Map := Podmander.Controller.Agent.Repository.Load_All (Ctrl.DB);
         Cur    : constant Podmander.Types.Agent_Maps.Cursor := Loaded.Find ("web-1");
      begin
         Assert (Podmander.Types.Agent_Maps.Has_Element (Cur), "Agent should be in DB after heartbeat");
         Assert
           (Podmander.Types.Agent_Maps.Element (Cur).State = Podmander.Types.Registered,
            "Expected state to transition to Registered");
      end;
   end Test_Handle_Heartbeat_Reconnect;

   -- Test: Make_Listening_Controller loads an existing secret from DB
   procedure Test_Controller_Startup_Loads_Secret (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Database;
      DB_Path : constant String := Unique_Temp_Path;
      Config  : Podmander.Controller.Controller_Config;
   begin
      -- Pre-seed a registration secret in the DB via a separate connection
      declare
         Pre_Handle : DB_Handle := Open (DB_Path);
      begin
         Set_Setting (Pre_Handle, "registration_secret", "pre_seeded_secret_1234567890123456");
      end;

      Podmander.Controller.Set_DB_Path (Config, DB_Path);
      Podmander.Controller.Set_Bind_Address (Config, "tcp://127.0.0.1:9998");

      declare
         Ctrl : constant Podmander.Controller.Controller_Instance :=
           Podmander.Controller.Make_Listening_Controller (Config);
      begin
         Assert
           (Podmander.Enrollment.Get_Secret (Ctrl.Config.Enrollment) = "pre_seeded_secret_1234567890123456",
            "Controller should load pre-seeded registration secret from DB");
      end;
      Cleanup_DB (DB_Path);
   exception
      when others =>
         Cleanup_DB (DB_Path);
         raise;
   end Test_Controller_Startup_Loads_Secret;

   -- Test: Make_Listening_Controller generates a new secret when none exists
   procedure Test_Controller_Startup_Generates_Secret (T : in out AUnit.Test_Cases.Test_Case'Class) is
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
         Loaded_Secret : constant String := Podmander.Enrollment.Get_Secret (Ctrl.Config.Enrollment);
      begin
         Assert (Loaded_Secret'Length > 0, "Controller should have generated a non-empty secret");
      end;

      -- Verify the secret was persisted via a separate connection
      declare
         Post_Handle      : DB_Handle := Open (DB_Path);
         Persisted_Secret : constant String := Get_Setting (Post_Handle, "registration_secret");
      begin
         Assert (Persisted_Secret'Length > 0, "A registration secret should have been persisted to DB");
      end;
      Cleanup_DB (DB_Path);
   exception
      when others =>
         Cleanup_DB (DB_Path);
         raise;
   end Test_Controller_Startup_Generates_Secret;

   -- Test: Handle_Deployment_Result logs warning when no Service_Version exists
   -- (defensive: should not crash even if version lookup fails)
   procedure Test_Handle_Deploy_Result_No_Version (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler := Make_Handler (Ctrl'Access, "node-1");
      Res  : constant Podmander.Messages.Deployment_Results.Deployment_Result :=
        (Catalog_Id    => 0,
         Code          => Podmander.Messages.Result_Codes.Ok,
         Service_Name  => To_Unbounded_String ("web"),
         Error_Message => Null_Unbounded_String);
   begin
      -- No Service_Version created for "web"  -- this should not crash
      H.Handle_Deployment_Result (Res);
      -- If we get here without crashing, the defensive handler worked
      Assert (True, "Handle_Deployment_Result should not crash without version");
   end Test_Handle_Deploy_Result_No_Version;

   -- Test: Handle_Stack_Submission with valid enrollment secret delegates
   -- to Stack_Submission.Submit and registers a service.
   procedure Test_Handle_Stack_Submission_Valid_Secret
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "cli-1");
      Cmd  : constant Podmander.Messages.Stack_Submissions.Stack_Submission :=
        (TOML =>
           To_Unbounded_String
             ("[service.web]" & ASCII.LF
              & "image = ""nginx:latest""" & ASCII.LF),
         Enrollment_Secret => To_Unbounded_String ("secret"));
   begin
      H.Handle_Stack_Submission (Cmd);
      -- Verify the service was registered in the DB
      declare
         Svc : constant Podmander.Controller.Service.Service :=
           Svc_Repo.Get_By_Name (Ctrl.DB, "web");
         pragma Unreferenced (Svc);
      begin
         null;  --  Get_By_Name raises Database_Error if not found
      end;
      Assert (True, "Handle_Stack_Submission with valid secret should register service");
   exception
      when Podmander.Database.Database_Error =>
         Assert (False, "Expected service 'web' to be registered in DB");
   end Test_Handle_Stack_Submission_Valid_Secret;

   -- Test: Handle_Stack_Submission with wrong enrollment secret does NOT
   -- delegate and does NOT register any service.
   procedure Test_Handle_Stack_Submission_Bad_Secret
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "cli-1");
      Cmd  : constant Podmander.Messages.Stack_Submissions.Stack_Submission :=
        (TOML =>
           To_Unbounded_String
             ("[service.web]" & ASCII.LF
              & "image = ""nginx:latest""" & ASCII.LF),
         Enrollment_Secret => To_Unbounded_String ("wrong_secret"));
   begin
      H.Handle_Stack_Submission (Cmd);
      -- Verify no service was registered in the DB
      declare
         Svc : constant Podmander.Controller.Service.Service :=
           Svc_Repo.Get_By_Name (Ctrl.DB, "web");
         pragma Unreferenced (Svc);
      begin
         Assert (False, "Expected no service registered with wrong secret");
      end;
   exception
      when Podmander.Database.Database_Error =>
         --  Expected: no service "web" found
         null;
   end Test_Handle_Stack_Submission_Bad_Secret;

   -- Test: Handle_Stack_Submission with valid secret but invalid TOML does NOT
   -- register any service.
   procedure Test_Handle_Stack_Submission_Invalid_TOML
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "cli-1");
      Cmd  : constant Podmander.Messages.Stack_Submissions.Stack_Submission :=
        (TOML =>
           To_Unbounded_String
             ("[service.web]" & ASCII.LF
              & "ports = [""80:80""" & ASCII.LF),
         -- Missing closing bracket: invalid TOML syntax
         Enrollment_Secret => To_Unbounded_String ("secret"));
   begin
      H.Handle_Stack_Submission (Cmd);
      -- Verify no service was registered (parse failed)
      declare
         Svc : constant Podmander.Controller.Service.Service :=
           Svc_Repo.Get_By_Name (Ctrl.DB, "web");
         pragma Unreferenced (Svc);
      begin
         Assert (False, "Expected no service registered with invalid TOML");
      end;
   exception
      when Podmander.Database.Database_Error =>
         --  Expected: no service "web" found
         null;
   end Test_Handle_Stack_Submission_Invalid_TOML;

   -- Test: Stack_Submission.Submit returns error detail via 'Image
   -- when given invalid TOML.
   procedure Test_Submit_Registration_Failed
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
Result : constant Podmander.Controller.Stack_Submission.Submission_Result :=
         Podmander.Controller.Stack_Submission.Submit
           (Ctrl.DB,
            "[service.web]" & ASCII.LF
            & "ports = [""80:80""" & ASCII.LF);
   begin
      -- Submit should have returned Ok = False due to invalid TOML
      Assert (not Result.Ok, "Submit with invalid TOML should return Ok = False");
      Assert
        (To_String (Result.Message)'Length > 0,
         "Submit error message should not be empty");
   end Test_Submit_Registration_Failed;

   overriding
   procedure Register_Tests (T : in out Controller_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Dispatch_Registration_Request'Access,
         "Registration_Request.Dispatch_To routes to Handle_Registration_Request");
      Register_Routine (T, Test_Dispatch_Heartbeat'Access, "Heartbeat_Message.Dispatch_To routes to Handle_Heartbeat");
      Register_Routine (T, Test_Dispatch_Polymorphic'Access, "Polymorphic Dispatch_To routes to concrete handler");
      Register_Routine
        (T, Test_Dispatch_Response_Raises'Access, "Registration_Response.Dispatch_To raises Program_Error");
      Register_Routine
        (T, Test_Handle_Registration_Request_Adds_Agent'Access, "Handle_Registration_Request adds agent (no socket)");
      Register_Routine
        (T, Test_Handle_Heartbeat_Updates_Last_Seen'Access, "Handle_Heartbeat updates Last_Seen for known agent");
      Register_Routine (T, Test_Handle_Heartbeat_Unknown_Agent'Access, "Handle_Heartbeat ignores unknown agent");
      Register_Routine
        (T, Test_Handle_Heartbeat_Reconnect'Access, "Handle_Heartbeat transitions Lost agent to Registered");
      Register_Routine (T, Test_Controller_DB_Path_Accessors'Access, "Set_DB_Path / Get_DB_Path round-trip");
      Register_Routine (T, Test_Controller_Make_With_DB'Access, "Make_Listening_Controller with memory DB");
      Register_Routine (T, Test_Startup_Loading'Access, "Agents persist across database connections (restart)");
      Register_Routine
        (T, Test_Controller_Startup_Loads_Secret'Access, "Controller loads pre-seeded registration secret from DB");
      Register_Routine
        (T, Test_Controller_Startup_Generates_Secret'Access, "Controller generates new secret when none exists");
      Register_Routine
        (T, Test_Handle_Deploy_Result_No_Version'Access, "Handle_Deploy_Result logs warning when no version exists");
      Register_Routine
        (T,
         Test_Handle_Stack_Submission_Valid_Secret'Access,
         "Handle_Stack_Submission with valid secret registers service");
      Register_Routine
        (T,
         Test_Handle_Stack_Submission_Bad_Secret'Access,
         "Handle_Stack_Submission with bad secret does not register");
      Register_Routine
        (T,
         Test_Handle_Stack_Submission_Invalid_TOML'Access,
         "Handle_Stack_Submission with invalid TOML does not register");
      Register_Routine
        (T,
         Test_Submit_Registration_Failed'Access,
         "Stack_Submission.Submit returns error detail on invalid TOML");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Controller_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller_Tests;
