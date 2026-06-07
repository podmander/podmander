--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Registration_Responses is

   use Ada.Strings.Unbounded;

   -- Controller -> Agent: confirm registration.
   -- Outbound only; Dispatch_To raises Program_Error because Decode never
   -- produces a Registration_Response from inbound traffic.
   type Registration_Response is new Registration_Response_Type with record
      Connection_Id : Unbounded_String;
   end record;

   overriding
   procedure Encode
     (Self : Registration_Response; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To
     (Self : Registration_Response; H : in out Message_Handler'Class);

end Podmander.Messages.Registration_Responses;
