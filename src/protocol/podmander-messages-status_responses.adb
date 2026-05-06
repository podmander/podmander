--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Messages.Status_Responses is

   overriding procedure Encode
     (Self : Status_Response;
      Msg  : in out CZMQ.Messages.Message) is
   begin
      Msg.Add_String (Status_Ack_Kind);
      Msg.Add_String (To_String (Self.Containers));
   end Encode;

   overriding procedure Dispatch_To
     (Self : Status_Response;
      H    : in out Message_Handler'Class) is
   begin
      H.Handle_Status_Response (Self);
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 1 then
         raise Decode_Error with "status_ack: missing containers frame";
      end if;
      return Status_Response'
        (Containers => To_Unbounded_String (Msg.Pop_String));
   end Decode_Impl;

begin
   Register (Status_Ack_Kind, Decode_Impl'Access);
end Podmander.Messages.Status_Responses;
