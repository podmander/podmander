--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Messages;

package Podmander.Messages.Deployment_Commands is

   use Ada.Strings.Unbounded;

   -- Controller -> Agent: deploy a service Quadlet
   type Deployment_Command is new Deployment_Command_Type with record
      Catalog_Id   : Catalog_Id_Type := Legacy_Catalog_Id;
      Service_Name : Unbounded_String;
      Quadlet      : Unbounded_String;
   end record;

   overriding
   procedure Encode
     (Self : Deployment_Command; Msg : in out CZMQ.Messages.Message);

   overriding
   procedure Dispatch_To
     (Self : Deployment_Command; H : in out Message_Handler'Class);

end Podmander.Messages.Deployment_Commands;
