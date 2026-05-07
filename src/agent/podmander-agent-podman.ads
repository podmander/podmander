--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Host-side Podman/Quadlet operations invoked by the agent.

with Podmander.Messages.Deploy_Results;

package Podmander.Agent.Podman is

   --  Install a Quadlet-based service: write the .container file under
   --  ~/.config/containers/systemd, reload systemd, and start the unit.
   function Install_Quadlet
     (Service_Name : String;
      Quadlet      : String)
      return Podmander.Messages.Deploy_Results.Deploy_Result;

end Podmander.Agent.Podman;
