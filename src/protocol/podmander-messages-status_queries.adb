--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Status_Queries is

   overriding
   procedure Encode (Self : Status_Query; Msg : in out CZMQ.Messages.Message)
   is
      pragma Unreferenced (Self);
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Status_Kind);
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Status_Query; H : in out Message_Handler'Class) is
   begin
      H.Handle_Status_Query (Self);
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class
   is
      pragma Unreferenced (Obj);
   begin
      return Status_Query'(null record);
   end Decode_Impl;

begin
   Register (Status_Kind, Decode_Impl'Access);
end Podmander.Messages.Status_Queries;
