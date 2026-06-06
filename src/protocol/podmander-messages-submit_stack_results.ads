--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Submit_Stack_Results is

   use Ada.Strings.Unbounded;

   -- Controller -> Operator: result of a stack submission
   type Submit_Stack_Result is new Submit_Stack_Result_Type with record
      Success : Boolean := False;
      Message : Unbounded_String;
   end record;

   overriding
   procedure Encode
     (Self : Submit_Stack_Result; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To
     (Self : Submit_Stack_Result; H : in out Message_Handler'Class);

end Podmander.Messages.Submit_Stack_Results;
