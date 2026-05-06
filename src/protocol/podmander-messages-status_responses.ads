--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Status_Responses is

   use Ada.Strings.Unbounded;

   --  Agent -> Controller: report running container status
   type Status_Response is new Status_Response_Type with record
      Containers : Unbounded_String;
      --  Tab-separated name/status pairs, one per line
   end record;

   overriding procedure Encode
     (Self : Status_Response;
      Msg  : in out CZMQ.Messages.Message);

   overriding procedure Dispatch_To
     (Self : Status_Response;
      H    : in out Message_Handler'Class);

end Podmander.Messages.Status_Responses;
