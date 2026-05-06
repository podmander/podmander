--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller;
with Podmander.Enrollment;
with Podmander.Controller.Message_Handlers;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Deploy_Commands;
with Podmander.Messages.Deploy_Results;
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Status_Responses;
with Podmander.Messages.Register_Requests;
with Podmander.Messages.Register_Responses;
with Podmander.Types;

package body Podmander.Controller_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   type Controller_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name
     (T : Controller_Test) return AUnit.Message_String
   is (AUnit.Format ("Controller Message Dispatch"));

   overriding procedure Register_Tests (T : in out Controller_Test);

   --  A Message_Handler that records which primitive was invoked and
   --  a copy of the received message. Used to verify Dispatch_To routes
   --  polymorphically to the right typed handler method.
   type Spy_Kind is (None, Register_Seen, Heartbeat_Seen,
                     Deploy_Command_Seen, Deploy_Result_Seen,
                     Status_Query_Seen, Status_Response_Seen);

   package Reg_Reqs renames Podmander.Messages.Register_Requests;
   package Heartbeats renames Podmander.Messages.Heartbeats;

   type Spy_Handler is limited new Podmander.Messages.Message_Handler
   with record
      Kind             : Spy_Kind := None;
      Last_Register    : Reg_Reqs.Register_Request;
      Last_Heartbeat   : Heartbeats.Heartbeat_Message;
      Last_Deploy_Cmd  : Podmander.Messages.Deploy_Commands.Deploy_Command;
      Last_Deploy_Res  : Podmander.Messages.Deploy_Results.Deploy_Result;
      Last_Status_Resp : Podmander.Messages.Status_Responses.Status_Response;
   end record;

   overriding procedure Handle_Register_Request
     (H : in out Spy_Handler;
      M : Podmander.Messages.Register_Request_Type'Class);

   overriding procedure Handle_Heartbeat
     (H : in out Spy_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class);

   overriding procedure Handle_Deploy_Command
     (H : in out Spy_Handler;
      M : Podmander.Messages.Deploy_Command_Type'Class);

   overriding procedure Handle_Deploy_Result
     (H : in out Spy_Handler;
      M : Podmander.Messages.Deploy_Result_Type'Class);

   overriding procedure Handle_Status_Query
     (H : in out Spy_Handler;
      M : Podmander.Messages.Status_Query_Type'Class);

   overriding procedure Handle_Status_Response
     (H : in out Spy_Handler;
      M : Podmander.Messages.Status_Response_Type'Class);

   overriding procedure Handle_Register_Request
     (H : in out Spy_Handler;
      M : Podmander.Messages.Register_Request_Type'Class) is
   begin
      H.Kind := Register_Seen;
      H.Last_Register :=
        Podmander.Messages.Register_Requests.Register_Request (M);
   end Handle_Register_Request;

   overriding procedure Handle_Heartbeat
     (H : in out Spy_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class) is
   begin
      H.Kind := Heartbeat_Seen;
      H.Last_Heartbeat :=
        Podmander.Messages.Heartbeats.Heartbeat_Message (M);
   end Handle_Heartbeat;

   overriding procedure Handle_Deploy_Command
     (H : in out Spy_Handler;
      M : Podmander.Messages.Deploy_Command_Type'Class) is
   begin
      H.Kind := Deploy_Command_Seen;
      H.Last_Deploy_Cmd :=
        Podmander.Messages.Deploy_Commands.Deploy_Command (M);
   end Handle_Deploy_Command;

   overriding procedure Handle_Deploy_Result
     (H : in out Spy_Handler;
      M : Podmander.Messages.Deploy_Result_Type'Class) is
   begin
      H.Kind := Deploy_Result_Seen;
      H.Last_Deploy_Res :=
        Podmander.Messages.Deploy_Results.Deploy_Result (M);
   end Handle_Deploy_Result;

   overriding procedure Handle_Status_Query
     (H : in out Spy_Handler;
      M : Podmander.Messages.Status_Query_Type'Class) is
      pragma Unreferenced (M);
   begin
      H.Kind := Status_Query_Seen;
   end Handle_Status_Query;

   overriding procedure Handle_Status_Response
     (H : in out Spy_Handler;
      M : Podmander.Messages.Status_Response_Type'Class) is
   begin
      H.Kind := Status_Response_Seen;
      H.Last_Status_Resp :=
        Podmander.Messages.Status_Responses.Status_Response (M);
   end Handle_Status_Response;

   --  Test: Register_Request.Dispatch_To routes to Handle_Register_Request
   procedure Test_Dispatch_Register_Request
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Register_Requests;
      Req : constant Register_Request :=
        (Agent_Name        => To_Unbounded_String ("web-1"),
         Enrollment_Secret => To_Unbounded_String ("secret"));
      Spy : Spy_Handler;
   begin
      Req.Dispatch_To (Spy);
      Assert (Spy.Kind = Register_Seen, "Expected Register_Seen");
      Assert
        (To_String (Spy.Last_Register.Agent_Name) = "web-1",
         "Expected agent_name web-1");
   end Test_Dispatch_Register_Request;

   --  Test: Heartbeat_Message.Dispatch_To routes to Handle_Heartbeat
   procedure Test_Dispatch_Heartbeat
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Heartbeats;
      HB : constant Heartbeat_Message :=
        (Agent_Id  => To_Unbounded_String ("node-1"),
         Timestamp => Ada.Calendar.Clock);
      Spy : Spy_Handler;
   begin
      HB.Dispatch_To (Spy);
      Assert (Spy.Kind = Heartbeat_Seen, "Expected Heartbeat_Seen");
      Assert
        (To_String (Spy.Last_Heartbeat.Agent_Id) = "node-1",
         "Expected agent_id node-1");
   end Test_Dispatch_Heartbeat;

   --  Test: Polymorphic dispatch through Protocol_Message'Class routes
   --  to the concrete type's handler.
   procedure Test_Dispatch_Polymorphic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Register_Requests;
      Req : constant Register_Request :=
        (Agent_Name        => To_Unbounded_String ("poly"),
         Enrollment_Secret => To_Unbounded_String ("secret"));
      Msg : constant Podmander.Messages.Protocol_Message'Class := Req;
      Spy : Spy_Handler;
   begin
      Msg.Dispatch_To (Spy);
      Assert
        (Spy.Kind = Register_Seen,
         "Polymorphic dispatch did not reach Register handler");
   end Test_Dispatch_Polymorphic;

   --  Test: Register_Response.Dispatch_To raises Program_Error
   procedure Test_Dispatch_Response_Raises
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Register_Responses;
      Resp : constant Register_Response :=
        (Node_Id => To_Unbounded_String ("n-1"));
      Spy : Spy_Handler;
   begin
      Resp.Dispatch_To (Spy);
      Assert (False, "Expected Program_Error from Register_Response");
   exception
      when Program_Error =>
         null;  --  Expected
   end Test_Dispatch_Response_Raises;

   --  Helpers for Controller_Handler tests that work without a live socket.
   function Make_Ctrl
     return Podmander.Controller.Controller_Instance is
   begin
      return C : Podmander.Controller.Controller_Instance do
         Podmander.Enrollment.Set_Secret
           (C.Config.Enrollment, "secret");
      end return;
   end Make_Ctrl;

   function Make_Handler
     (Ctrl : access Podmander.Controller.Controller_Instance;
      Identity : String)
     return Podmander.Controller.Message_Handlers.Controller_Handler is
   begin
      return
        (Ctrl     => Ctrl,
         Identity => To_Unbounded_String (Identity));
   end Make_Handler;

   --  Test: Handle_Register_Request adds the agent to the controller's map
   --  when Socket is null (reply Send is guarded).
   procedure Test_Handle_Register_Request_Adds_Agent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ctrl : aliased Podmander.Controller.Controller_Instance := Make_Ctrl;
      H    : Podmander.Controller.Message_Handlers.Controller_Handler :=
        Make_Handler (Ctrl'Access, "node-abc");
      Req  : constant Podmander.Messages.Register_Requests.Register_Request :=
        (Agent_Name        => To_Unbounded_String ("web-1"),
         Enrollment_Secret => To_Unbounded_String ("secret"));
   begin
      H.Handle_Register_Request (Req);
      Assert
        (Ctrl.Agents.Contains ("node-abc"),
         "Expected agent node-abc in Agents map");
   end Test_Handle_Register_Request_Adds_Agent;

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
        (Agent_Id  => To_Unbounded_String ("node-xyz"),
         Timestamp => Ada.Calendar.Clock);
   begin
      Ctrl.Agents.Insert ("node-xyz", Info);
      H.Handle_Heartbeat (HB);
      Assert
        (Ctrl.Agents ("node-xyz").Last_Seen > Past,
         "Last_Seen was not updated");
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
        (Agent_Id  => To_Unbounded_String ("unknown"),
         Timestamp => Ada.Calendar.Clock);
   begin
      H.Handle_Heartbeat (HB);
      Assert
        (Ctrl.Agents.Is_Empty,
         "Agents map mutated for unknown heartbeat");
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
        (Agent_Id  => To_Unbounded_String ("lost-node"),
         Timestamp => Ada.Calendar.Clock);
   begin
      Ctrl.Agents.Insert ("lost-node", Info);
      H.Handle_Heartbeat (HB);
      Assert
        (Ctrl.Agents ("lost-node").State = Podmander.Types.Registered,
         "Expected state to transition to Registered");
   end Test_Handle_Heartbeat_Reconnect;

   overriding procedure Register_Tests (T : in out Controller_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Dispatch_Register_Request'Access,
         "Register_Request.Dispatch_To routes to Handle_Register_Request");
      Register_Routine
        (T, Test_Dispatch_Heartbeat'Access,
         "Heartbeat_Message.Dispatch_To routes to Handle_Heartbeat");
      Register_Routine
        (T, Test_Dispatch_Polymorphic'Access,
         "Polymorphic Dispatch_To routes to concrete handler");
      Register_Routine
        (T, Test_Dispatch_Response_Raises'Access,
         "Register_Response.Dispatch_To raises Program_Error");
      Register_Routine
        (T, Test_Handle_Register_Request_Adds_Agent'Access,
         "Handle_Register_Request adds agent (no socket)");
      Register_Routine
        (T, Test_Handle_Heartbeat_Updates_Last_Seen'Access,
         "Handle_Heartbeat updates Last_Seen for known agent");
      Register_Routine
        (T, Test_Handle_Heartbeat_Unknown_Agent'Access,
         "Handle_Heartbeat ignores unknown agent");
      Register_Routine
        (T, Test_Handle_Heartbeat_Reconnect'Access,
         "Handle_Heartbeat transitions Lost agent to Registered");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Controller_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller_Tests;
