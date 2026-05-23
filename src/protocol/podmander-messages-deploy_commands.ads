--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Deploy_Commands is

   use Ada.Strings.Unbounded;

   --  Controller -> Agent: deploy a service Quadlet
   type Deploy_Command is new Deploy_Command_Type with record
      Catalog_Id   : Integer := 0;
      Service_Name : Unbounded_String;
      Quadlet      : Unbounded_String;
   end record;

   overriding
   procedure Encode (Self : Deploy_Command; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To (Self : Deploy_Command; H : in out Message_Handler'Class);

end Podmander.Messages.Deploy_Commands;
