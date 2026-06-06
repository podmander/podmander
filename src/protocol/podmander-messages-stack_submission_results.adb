--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with GNATCOLL.JSON;
with Podmander.Messages.JSON_Utils;

pragma Elaborate (Podmander.Messages);

package body Podmander.Messages.Stack_Submission_Results is

   overriding
   procedure Encode
     (Self : Stack_Submission_Result; Msg : in out CZMQ.Messages.Message)
   is
      Obj : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      JSON_Utils.Set_Kind (Obj, Stack_Submission_Result_Kind);
      if Self.Success then
         JSON_Utils.Set_Field (Obj, "success", "true");
      else
         JSON_Utils.Set_Field (Obj, "success", "false");
      end if;
      JSON_Utils.Set_Field (Obj, "message", To_String (Self.Message));
      Msg.Add_String (GNATCOLL.JSON.Write (Obj));
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Stack_Submission_Result; H : in out Message_Handler'Class) is
   begin
      H.Handle_Stack_Submission_Result (Self);
   end Dispatch_To;

   function Decode_Impl
     (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class is
      Success_Str : constant String := JSON_Utils.Get_Field (Obj, "success");
      Msg_Str     : constant String := JSON_Utils.Get_Field (Obj, "message");
   begin
      if Success_Str /= "true" and then Success_Str /= "false" then
         raise Podmander.Messages.Decode_Error with
           "Invalid success field: expected 'true' or 'false', got '"
           & Success_Str & "'";
      end if;
return
         Stack_Submission_Result'
           (Success => Success_Str = "true",
            Message => To_Unbounded_String (Msg_Str));
   end Decode_Impl;

begin
   Register (Stack_Submission_Result_Kind, Decode_Impl'Access);
end Podmander.Messages.Stack_Submission_Results;
