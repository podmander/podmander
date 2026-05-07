--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Messages.Deploy_Results is

   overriding procedure Encode
     (Self : Deploy_Result;
      Msg  : in out CZMQ.Messages.Message) is
   begin
      Msg.Add_String (Deploy_Ack_Kind);
      Msg.Add_String (RC.Encode_Code (Self.Code));
      Msg.Add_String (SU.To_String (Self.Service_Name));
      Msg.Add_String (SU.To_String (Self.Error_Message));
   end Encode;

   overriding procedure Dispatch_To
     (Self : Deploy_Result;
      H    : in out Message_Handler'Class) is
   begin
      H.Handle_Deploy_Result (Self);
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 3 then
         raise Decode_Error with "deploy_ack: missing payload frames";
      end if;
      declare
         Code        : constant RC.Result_Code :=
           RC.Decode_Code (Msg.Pop_String);
         Service_Name : constant String := Msg.Pop_String;
         Error_Msg    : constant String := Msg.Pop_String;
      begin
         return Deploy_Result'
           (Code          => Code,
            Service_Name  => SU.To_Unbounded_String (Service_Name),
            Error_Message => SU.To_Unbounded_String (Error_Msg));
      end;
   end Decode_Impl;

begin
   Register (Deploy_Ack_Kind, Decode_Impl'Access);
end Podmander.Messages.Deploy_Results;
