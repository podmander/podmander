--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Stack_Submission_Results is

   use Ada.Strings.Unbounded;

   -- Controller -> Operator: result of a stack submission
   type Stack_Submission_Result is new Stack_Submission_Result_Type with record
      Success : Boolean := False;
      Message : Unbounded_String;
   end record;

   overriding
   procedure Encode
     (Self : Stack_Submission_Result; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To
     (Self : Stack_Submission_Result; H : in out Message_Handler'Class);

end Podmander.Messages.Stack_Submission_Results;
