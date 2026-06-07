--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Heartbeats is

   overriding
   procedure Encode
     (Self : Heartbeat_Message; Msg : in out CZMQ.Messages.Message)
   is
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Heartbeat_Kind);
      JSON_Utils.Set_Field (Obj, "node_id", To_String (Self.Node_Id));
      JSON_Utils.Set_Field (Obj, "timestamp", Self.Timestamp);
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Heartbeat_Message; H : in out Message_Handler'Class) is
   begin
      H.Handle_Heartbeat (Self);
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class
   is
      Node_Id : constant String := JSON_Utils.Get_Field (Obj, "node_id");
   begin
      return
        Heartbeat_Message'
          (Node_Id   => To_Unbounded_String (Node_Id),
           Timestamp => JSON_Utils.Get_Field (Obj, "timestamp"));
   end Decode_Impl;

begin
   Register (Heartbeat_Kind, Decode_Impl'Access);
end Podmander.Messages.Heartbeats;
