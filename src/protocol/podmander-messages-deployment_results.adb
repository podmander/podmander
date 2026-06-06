--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Deployment_Results is

   overriding
   procedure Encode (Self : Deployment_Result; Msg : in out CZMQ.Messages.Message)
   is
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Deployment_Ack_Kind);
      JSON_Utils.Set_Field (Obj, "catalog_id", Self.Catalog_Id);
      JSON_Utils.Set_Field (Obj, "code", RC.Encode_Code (Self.Code));
      JSON_Utils.Set_Field (Obj, "service_name", SU.To_String (Self.Service_Name));
      JSON_Utils.Set_Field (Obj, "error_message", SU.To_String (Self.Error_Message));
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Deployment_Result; H : in out Message_Handler'Class) is
   begin
      H.Handle_Deployment_Result (Self);
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class is
      Service_Name : constant String := JSON_Utils.Get_Field (Obj, "service_name");
      Error_Msg    : constant String := JSON_Utils.Get_Field (Obj, "error_message");
   begin
      return
        Deployment_Result'
          (Catalog_Id    => JSON_Utils.Get_Field (Obj, "catalog_id"),
           Code          => RC.Decode_Code (JSON_Utils.Get_Field (Obj, "code")),
           Service_Name  => SU.To_Unbounded_String (Service_Name),
           Error_Message => SU.To_Unbounded_String (Error_Msg));
   end Decode_Impl;

begin
   Register (Deployment_Ack_Kind, Decode_Impl'Access);
end Podmander.Messages.Deployment_Results;
