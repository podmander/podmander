--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Registration_Responses is

   overriding
   procedure Encode
     (Self : Registration_Response; Msg : in out CZMQ.Messages.Message)
   is
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Registration_Response_Kind);
      JSON_Utils.Set_Field
        (Obj, "connection_id", To_String (Self.Connection_Id));
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Registration_Response; H : in out Message_Handler'Class)
   is
      pragma Unreferenced (Self, H);
   begin
      raise Program_Error with "Registration_Response is outbound-only";
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class
   is
      Connection_Id : constant String :=
        JSON_Utils.Get_Field (Obj, "connection_id");
   begin
      return
        Registration_Response'
          (Connection_Id => To_Unbounded_String (Connection_Id));
   end Decode_Impl;

begin
   Register (Registration_Response_Kind, Decode_Impl'Access);
end Podmander.Messages.Registration_Responses;
