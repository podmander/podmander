--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Messages.Registration_Responses is

   overriding procedure Encode
     (Self : Registration_Response;
      Msg  : in out CZMQ.Messages.Message) is
   begin
      Msg.Add_String (Registration_Response_Kind);
      Msg.Add_String (To_String (Self.Node_Id));
   end Encode;

   overriding procedure Dispatch_To
     (Self : Registration_Response;
      H    : in out Message_Handler'Class)
   is
      pragma Unreferenced (Self, H);
   begin
      raise Program_Error with "Registration_Response is outbound-only";
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 1 then
         raise Decode_Error with "registered: missing node_id frame";
      end if;
      return Registration_Response'
        (Node_Id => To_Unbounded_String (Msg.Pop_String));
   end Decode_Impl;

begin
   Register (Registration_Response_Kind, Decode_Impl'Access);
end Podmander.Messages.Registration_Responses;
