--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;
with Podmander.Messages.Result_Codes;

package Podmander.Messages.Deploy_Results is

   package SU renames Ada.Strings.Unbounded;
   package RC renames Podmander.Messages.Result_Codes;

   --  Agent -> Controller: result of a deploy command
   type Deploy_Result is new Deploy_Result_Type with record
      Code          : RC.Result_Code := RC.Ok;
      Service_Name  : SU.Unbounded_String;
      Error_Message : SU.Unbounded_String;
   end record;

   overriding
   procedure Encode (Self : Deploy_Result; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To
     (Self : Deploy_Result; H : in out Message_Handler'Class);

end Podmander.Messages.Deploy_Results;
