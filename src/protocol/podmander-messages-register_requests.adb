--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

package body Podmander.Messages.Register_Requests is

   overriding procedure Encode
     (Self : Register_Request;
      Msg  : in out CZMQ.Messages.Message) is
   begin
      Msg.Add_String (Register_Kind);
      Msg.Add_String (To_String (Self.Agent_Name));
   end Encode;

   overriding procedure Dispatch_To
     (Self : Register_Request;
      H    : in out Message_Handler'Class) is
   begin
      H.Handle_Register_Request (Self);
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 1 then
         raise Decode_Error with "register: missing agent_name frame";
      end if;
      return Register_Request'
        (Agent_Name => To_Unbounded_String (Msg.Pop_String));
   end Decode_Impl;

begin
   Register (Register_Kind, Decode_Impl'Access);
end Podmander.Messages.Register_Requests;
