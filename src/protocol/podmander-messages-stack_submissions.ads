--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Stack_Submissions is

   use Ada.Strings.Unbounded;

   -- Operator -> Controller: submit a stack TOML definition
   type Stack_Submission is new Stack_Submission_Type with record
      TOML              : Unbounded_String;
      Enrollment_Secret : Unbounded_String;
   end record;

   overriding
   procedure Encode
     (Self : Stack_Submission; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To
     (Self : Stack_Submission; H : in out Message_Handler'Class);

end Podmander.Messages.Stack_Submissions;
