--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Submit_Stacks is

   use Ada.Strings.Unbounded;

   -- Operator -> Controller: submit a stack TOML definition
   type Submit_Stack is new Submit_Stack_Type with record
      TOML              : Unbounded_String;
      Enrollment_Secret : Unbounded_String;
   end record;

   overriding
   procedure Encode
     (Self : Submit_Stack; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To
     (Self : Submit_Stack; H : in out Message_Handler'Class);

end Podmander.Messages.Submit_Stacks;
