--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Deployment_Commands is

   overriding
   procedure Encode (Self : Deployment_Command; Msg : in out CZMQ.Messages.Message)
   is
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Deployment_Kind);
      JSON_Utils.Set_Field (Obj, "catalog_id", Self.Catalog_Id);
      JSON_Utils.Set_Field (Obj, "service_name", To_String (Self.Service_Name));
      JSON_Utils.Set_Field (Obj, "quadlet", To_String (Self.Quadlet));
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Deployment_Command; H : in out Message_Handler'Class) is
   begin
      H.Handle_Deployment_Command (Self);
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class is
      Service_Name : constant String := JSON_Utils.Get_Field (Obj, "service_name");
      Quadlet      : constant String := JSON_Utils.Get_Field (Obj, "quadlet");
   begin
      return
        Deployment_Command'
          (Catalog_Id   => JSON_Utils.Get_Field (Obj, "catalog_id"),
           Service_Name => To_Unbounded_String (Service_Name),
           Quadlet      => To_Unbounded_String (Quadlet));
   end Decode_Impl;

begin
   Register (Deployment_Kind, Decode_Impl'Access);
end Podmander.Messages.Deployment_Commands;
