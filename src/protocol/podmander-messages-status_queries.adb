--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Messages.Status_Queries is

   overriding
   procedure Encode (Self : Status_Query; Msg : in out CZMQ.Messages.Message)
   is
      pragma Unreferenced (Self);
   begin
      Msg.Add_String (Status_Kind);
   end Encode;

   overriding
   procedure Dispatch_To
     (Self : Status_Query; H : in out Message_Handler'Class) is
   begin
      H.Handle_Status_Query (Self);
   end Dispatch_To;

   function Decode_Impl
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class
   is
      pragma Unreferenced (Msg);
   begin
      return Status_Query'(null record);
   end Decode_Impl;

begin
   Register (Status_Kind, Decode_Impl'Access);
end Podmander.Messages.Status_Queries;
