--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar.Formatting;

package body Podmander.Messages.Heartbeats is

   overriding
   procedure Encode
     (Self : Heartbeat_Message; Msg : in out CZMQ.Messages.Message) is
   begin
      Msg.Add_String (Heartbeat_Kind);
      Msg.Add_String (To_String (Self.Node_Id));
      Msg.Add_String (Ada.Calendar.Formatting.Image (Self.Timestamp));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Heartbeat_Message; H : in out Message_Handler'Class) is
   begin
      H.Handle_Heartbeat (Self);
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class is
   begin
      if Msg.Size < 2 then
         raise Decode_Error with "heartbeat: missing payload frames";
      end if;
      declare
         Node_Id   : constant String := Msg.Pop_String;
         Timestamp : constant String := Msg.Pop_String;
      begin
         return
           Heartbeat_Message'
             (Node_Id   => To_Unbounded_String (Node_Id),
              Timestamp => Ada.Calendar.Formatting.Value (Timestamp));
      end;
   end Decode_Impl;

begin
   Register (Heartbeat_Kind, Decode_Impl'Access);
end Podmander.Messages.Heartbeats;
