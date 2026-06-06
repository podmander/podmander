--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Submit_Stacks is

   overriding
   procedure Encode (Self : Submit_Stack; Msg : in out CZMQ.Messages.Message)
   is
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Submit_Stack_Kind);
      JSON_Utils.Set_Field (Obj, "toml", To_String (Self.TOML));
      JSON_Utils.Set_Field (Obj, "enrollment_secret", To_String (Self.Enrollment_Secret));
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Submit_Stack; H : in out Message_Handler'Class) is
   begin
      H.Handle_Submit_Stack (Self);
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class is
      TOML              : constant String := JSON_Utils.Get_Field (Obj, "toml");
      Enrollment_Secret : constant String := JSON_Utils.Get_Field (Obj, "enrollment_secret");
   begin
      return
        Submit_Stack'
          (TOML              => To_Unbounded_String (TOML),
           Enrollment_Secret => To_Unbounded_String (Enrollment_Secret));
   end Decode_Impl;

begin
   Register (Submit_Stack_Kind, Decode_Impl'Access);
end Podmander.Messages.Submit_Stacks;
