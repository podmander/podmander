--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Registration_Requests is

   overriding
   procedure Encode
     (Self : Registration_Request; Msg : in out CZMQ.Messages.Message)
   is
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Registration_Request_Kind);
      JSON_Utils.Set_Field (Obj, "agent_name", To_String (Self.Agent_Name));
      JSON_Utils.Set_Field (Obj, "enrollment_secret", To_String (Self.Enrollment_Secret));
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Registration_Request; H : in out Message_Handler'Class) is
   begin
      H.Handle_Registration_Request (Self);
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class is
      Agent_Name : constant String :=
        JSON_Utils.Get_Field (Obj, "agent_name");
      Enrollment_Secret : constant String :=
        JSON_Utils.Get_Field (Obj, "enrollment_secret");
   begin
      return
        Registration_Request'
          (Agent_Name        => To_Unbounded_String (Agent_Name),
           Enrollment_Secret => To_Unbounded_String (Enrollment_Secret));
   end Decode_Impl;

begin
   Register (Registration_Request_Kind, Decode_Impl'Access);
end Podmander.Messages.Registration_Requests;