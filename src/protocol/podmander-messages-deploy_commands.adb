--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Messages.Deploy_Commands is

   overriding
   procedure Encode (Self : Deploy_Command; Msg : in out CZMQ.Messages.Message)
   is
   begin
      Msg.Add_String (Deploy_Kind);
      Msg.Add_String (To_String (Self.Service_Name));
      Msg.Add_String (To_String (Self.Quadlet));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Deploy_Command; H : in out Message_Handler'Class) is
   begin
      H.Handle_Deploy_Command (Self);
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 2 then
         raise Decode_Error with "deploy: missing payload frames";
      end if;
      return
        Deploy_Command'
          (Service_Name => To_Unbounded_String (Msg.Pop_String),
           Quadlet      => To_Unbounded_String (Msg.Pop_String));
   end Decode_Impl;

begin
   Register (Deploy_Kind, Decode_Impl'Access);
end Podmander.Messages.Deploy_Commands;
