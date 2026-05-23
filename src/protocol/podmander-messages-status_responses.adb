--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Messages.Status_Responses is

   overriding
   procedure Encode (Self : Status_Response; Msg : in out CZMQ.Messages.Message) is
   begin
      Msg.Add_String (Status_Ack_Kind);
      Msg.Add_String (RC.Encode_Code (Self.Code));
      Msg.Add_String (SU.To_String (Self.Containers));
      Msg.Add_String (SU.To_String (Self.Error_Message));
   end Encode;

   overriding
   procedure Dispatch_To (Self : Status_Response; H : in out Message_Handler'Class) is
   begin
      H.Handle_Status_Response (Self);
   end Dispatch_To;

   function Decode_Impl (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 3 then
         raise Decode_Error with "status_ack: missing payload frames";
      end if;
      declare
         Code          : constant RC.Result_Code := RC.Decode_Code (Msg.Pop_String);
         Containers    : constant String := Msg.Pop_String;
         Error_Message : constant String := Msg.Pop_String;
      begin
         return
           Status_Response'
             (Code          => Code,
              Containers    => SU.To_Unbounded_String (Containers),
              Error_Message => SU.To_Unbounded_String (Error_Message));
      end;
   end Decode_Impl;

begin
   Register (Status_Ack_Kind, Decode_Impl'Access);
end Podmander.Messages.Status_Responses;
