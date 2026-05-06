--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Messages.Deploy_Results;

package Podmander.Agent.Deployer is

   --  Execute a quadlet-based deployment: write the .container file,
   --  reload systemd, and start the service.
   function Execute_Deploy
     (Service_Name : String;
      Quadlet      : String)
      return Podmander.Messages.Deploy_Results.Deploy_Result;

end Podmander.Agent.Deployer;
