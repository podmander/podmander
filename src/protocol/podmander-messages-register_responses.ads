--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Register_Responses is

   use Ada.Strings.Unbounded;

   --  Controller -> Agent: confirm registration.
   --  Outbound only; Dispatch_To raises Program_Error because Decode never
   --  produces a Register_Response from inbound traffic.
   type Register_Response is new Register_Response_Type with record
      Node_Id : Unbounded_String;
   end record;

   overriding procedure Encode
     (Self : Register_Response;
      Msg  : in out CZMQ.Messages.Message);

   overriding procedure Dispatch_To
     (Self : Register_Response;
      H    : in out Message_Handler'Class);

end Podmander.Messages.Register_Responses;
