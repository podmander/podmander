--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Status_Responses is

   overriding
   procedure Encode
     (Self : Status_Response; Msg : in out CZMQ.Messages.Message)
   is
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Status_Ack_Kind);
      JSON_Utils.Set_Field (Obj, "code", RC.Encode_Code (Self.Code));
      JSON_Utils.Set_Field (Obj, "containers", SU.To_String (Self.Containers));
      JSON_Utils.Set_Field
        (Obj, "error_message", SU.To_String (Self.Error_Message));
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Status_Response; H : in out Message_Handler'Class) is
   begin
      H.Handle_Status_Response (Self);
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class
   is
      Code          : constant RC.Result_Code :=
        RC.Decode_Code (JSON_Utils.Get_Field (Obj, "code"));
      Containers    : constant String :=
        JSON_Utils.Get_Field (Obj, "containers");
      Error_Message : constant String :=
        JSON_Utils.Get_Field (Obj, "error_message");
   begin
      return
        Status_Response'
          (Code          => Code,
           Containers    => SU.To_Unbounded_String (Containers),
           Error_Message => SU.To_Unbounded_String (Error_Message));
   end Decode_Impl;

begin
   Register (Status_Ack_Kind, Decode_Impl'Access);
end Podmander.Messages.Status_Responses;
