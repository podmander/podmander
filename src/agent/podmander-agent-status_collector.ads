--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Messages.Status_Responses;

package Podmander.Agent.Status_Collector is

   --  Collect running container status from Podman.
   --  Returns a Status_Response with container names and statuses.
   function Collect_Status
      return Podmander.Messages.Status_Responses.Status_Response;

end Podmander.Agent.Status_Collector;
