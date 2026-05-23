--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ.Messages;

package Podmander.Messages.Status_Queries is

   --  Controller -> Agent: request running container status
   type Status_Query is new Status_Query_Type with null record;

   overriding
   procedure Encode (Self : Status_Query; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To (Self : Status_Query; H : in out Message_Handler'Class);

end Podmander.Messages.Status_Queries;
