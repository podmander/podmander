--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;
with Podmander.Messages.Result_Codes;

package Podmander.Messages.Status_Responses is

   package SU renames Ada.Strings.Unbounded;
   package RC renames Podmander.Messages.Result_Codes;

   --  Agent -> Controller: report running container status.
   --  Containers holds tab-separated name/status pairs (one per line) when the
   --  query succeeded; empty otherwise. Error_Message holds the error detail
   --  when Code /= Ok; empty on success.
   type Status_Response is new Status_Response_Type with record
      Code          : RC.Result_Code := RC.Ok;
      Containers    : SU.Unbounded_String;
      Error_Message : SU.Unbounded_String;
   end record;

   overriding procedure Encode
     (Self : Status_Response;
      Msg  : in out CZMQ.Messages.Message);

   overriding procedure Dispatch_To
     (Self : Status_Response;
      H    : in out Message_Handler'Class);

end Podmander.Messages.Status_Responses;
