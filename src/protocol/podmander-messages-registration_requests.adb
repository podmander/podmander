--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Messages.Registration_Requests is

   overriding procedure Encode
     (Self : Registration_Request;
      Msg  : in out CZMQ.Messages.Message) is
   begin
      Msg.Add_String (Registration_Request_Kind);
      Msg.Add_String (To_String (Self.Agent_Name));
      Msg.Add_String (To_String (Self.Enrollment_Secret));
   end Encode;

   overriding procedure Dispatch_To
     (Self : Registration_Request;
      H    : in out Message_Handler'Class) is
   begin
      H.Handle_Registration_Request (Self);
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 2 then
         raise Decode_Error with "registration: missing frames";
      end if;
      return Registration_Request'
        (Agent_Name        => To_Unbounded_String (Msg.Pop_String),
         Enrollment_Secret => To_Unbounded_String (Msg.Pop_String));
   end Decode_Impl;

begin
   Register (Registration_Request_Kind, Decode_Impl'Access);
end Podmander.Messages.Registration_Requests;
