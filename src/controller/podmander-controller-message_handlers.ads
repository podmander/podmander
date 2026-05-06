--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.Messages;

package Podmander.Controller.Message_Handlers is

   use Ada.Strings.Unbounded;

   --  Concrete Message_Handler that mutates a Controller_Instance.
   --  Exposed as a public child so tests can drive it without a live socket.
   type Controller_Handler is limited new Podmander.Messages.Message_Handler
   with record
      Ctrl     : access Controller_Instance;
      Identity : Unbounded_String;
   end record;

   overriding procedure Handle_Register_Request
     (H : in out Controller_Handler;
      M : Podmander.Messages.Register_Request_Type'Class);

   overriding procedure Handle_Heartbeat
     (H : in out Controller_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class);

   overriding procedure Handle_Deploy_Command
     (H : in out Controller_Handler;
      M : Podmander.Messages.Deploy_Command_Type'Class);

   overriding procedure Handle_Deploy_Result
     (H : in out Controller_Handler;
      M : Podmander.Messages.Deploy_Result_Type'Class);

   overriding procedure Handle_Status_Query
     (H : in out Controller_Handler;
      M : Podmander.Messages.Status_Query_Type'Class);

   overriding procedure Handle_Status_Response
     (H : in out Controller_Handler;
      M : Podmander.Messages.Status_Response_Type'Class);

end Podmander.Controller.Message_Handlers;
