--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Registration_Requests is

   use Ada.Strings.Unbounded;

   --  Agent -> Controller: request registration
   type Registration_Request is new Registration_Request_Type with record
      Agent_Name        : Unbounded_String;
      Enrollment_Secret : Unbounded_String;
   end record;

   overriding
   procedure Encode
     (Self : Registration_Request; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To
     (Self : Registration_Request; H : in out Message_Handler'Class);

end Podmander.Messages.Registration_Requests;
