--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Register_Requests is

   use Ada.Strings.Unbounded;

   --  Agent -> Controller: request registration
   type Register_Request is new Register_Request_Type with record
      Agent_Name : Unbounded_String;
   end record;

   overriding procedure Encode
     (Self : Register_Request;
      Msg  : in out CZMQ.Messages.Message);

   overriding procedure Dispatch_To
     (Self : Register_Request;
      H    : in out Message_Handler'Class);

end Podmander.Messages.Register_Requests;
