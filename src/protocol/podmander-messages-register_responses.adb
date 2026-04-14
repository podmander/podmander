--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

package body Podmander.Messages.Register_Responses is

   overriding procedure Encode
     (Self : Register_Response;
      Msg  : in out CZMQ.Messages.Message) is
   begin
      Msg.Add_String (Registered_Kind);
      Msg.Add_String (To_String (Self.Node_Id));
   end Encode;

   overriding procedure Dispatch_To
     (Self : Register_Response;
      H    : in out Message_Handler'Class)
   is
      pragma Unreferenced (Self, H);
   begin
      raise Program_Error with "Register_Response is outbound-only";
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 1 then
         raise Decode_Error with "registered: missing node_id frame";
      end if;
      return Register_Response'
        (Node_Id => To_Unbounded_String (Msg.Pop_String));
   end Decode_Impl;

begin
   Register (Registered_Kind, Decode_Impl'Access);
end Podmander.Messages.Register_Responses;
