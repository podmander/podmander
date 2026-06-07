--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Messages;
with Podmander.Messages.Deployment_Results;
with Podmander.Messages.Status_Responses;

package Podmander.Agent.Message_Handlers is

   use Ada.Strings.Unbounded;

   -- Concrete Message_Handler for the agent.
   -- Receives commands from the controller and dispatches to the
   -- agent's host-side capability packages (currently: Podman).
   -- Accesses the socket through the agent instance, which owns
   -- the socket as a field managed by the CZMQ Open/Close API.
   type Agent_Handler is limited new Podmander.Messages.Message_Handler
   with record
      Agt : access Podmander.Agent.Agent_Instance;
   end record;

   overriding
   procedure Handle_Registration_Request
     (H : in out Agent_Handler;
      M : Podmander.Messages.Registration_Request_Type'Class);

   overriding
   procedure Handle_Heartbeat
     (H : in out Agent_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class);

   overriding
   procedure Handle_Deployment_Command
     (H : in out Agent_Handler;
      M : Podmander.Messages.Deployment_Command_Type'Class);

   overriding
   procedure Handle_Deployment_Result
     (H : in out Agent_Handler;
      M : Podmander.Messages.Deployment_Result_Type'Class);

   overriding
   procedure Handle_Status_Query
     (H : in out Agent_Handler;
      M : Podmander.Messages.Status_Query_Type'Class);

   overriding
   procedure Handle_Status_Response
     (H : in out Agent_Handler;
      M : Podmander.Messages.Status_Response_Type'Class);

   overriding
   procedure Handle_Stack_Submission
     (H : in out Agent_Handler;
      M : Podmander.Messages.Stack_Submission_Type'Class);

   overriding
   procedure Handle_Stack_Submission_Result
     (H : in out Agent_Handler;
      M : Podmander.Messages.Stack_Submission_Result_Type'Class);

   procedure Send_Deployment_Result
     (H      : in out Agent_Handler;
      Result : Podmander.Messages.Deployment_Results.Deployment_Result);

   procedure Send_Status_Response
     (H      : in out Agent_Handler;
      Result : Podmander.Messages.Status_Responses.Status_Response);

end Podmander.Agent.Message_Handlers;
