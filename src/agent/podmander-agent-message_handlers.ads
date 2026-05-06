--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Messages;
with Podmander.Messages.Deploy_Results;
with Podmander.Messages.Status_Responses;

package Podmander.Agent.Message_Handlers is

   use Ada.Strings.Unbounded;

   --  Concrete Message_Handler for the agent.
   --  Receives commands from the controller and dispatches to
   --  domain packages (Deployer, Status_Collector).
   type Agent_Handler is limited new Podmander.Messages.Message_Handler
   with record
      Agt : access Podmander.Agent.Agent_Instance;
   end record;

   overriding procedure Handle_Register_Request
     (H : in out Agent_Handler;
      M : Podmander.Messages.Register_Request_Type'Class);

   overriding procedure Handle_Heartbeat
     (H : in out Agent_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class);

   overriding procedure Handle_Deploy_Command
     (H : in out Agent_Handler;
      M : Podmander.Messages.Deploy_Command_Type'Class);

   overriding procedure Handle_Deploy_Result
     (H : in out Agent_Handler;
      M : Podmander.Messages.Deploy_Result_Type'Class);

   overriding procedure Handle_Status_Query
     (H : in out Agent_Handler;
      M : Podmander.Messages.Status_Query_Type'Class);

   overriding procedure Handle_Status_Response
     (H : in out Agent_Handler;
      M : Podmander.Messages.Status_Response_Type'Class);

   procedure Send_Deploy_Result
     (H      : in out Agent_Handler;
      Result : Podmander.Messages.Deploy_Results.Deploy_Result);

   procedure Send_Status_Response
     (H      : in out Agent_Handler;
      Result : Podmander.Messages.Status_Responses.Status_Response);

end Podmander.Agent.Message_Handlers;
