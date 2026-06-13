--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  The Supervisor performs one reconciliation pass over the Service Catalog
--  on each call to Tick: unscheduled entries are assigned a node via the
--  First_Available strategy, and Pending entries with a Registered agent are
--  deployed by sending a Deployment_Command through Socket.

with CZMQ.Sockets;
with Podmander.Database;

package Podmander.Controller.Supervisor is

   procedure Tick
     (DB     : in out Podmander.Database.DB_Handle;
      Socket : in out CZMQ.Sockets.Socket);
   --  One reconciliation pass over the Service Catalog: schedule unscheduled
   --  entries (First_Available strategy), then deploy pending ones, sending a
   --  Deployment_Command through Socket to the assigned node's registered agent.

   procedure Recover (DB : in out Podmander.Database.DB_Handle);
   --  Startup convergence: reset catalog entries left In_Progress by a
   --  previous crashed controller back to Pending so they are redeployed.
   --  Call once before the poll loop begins.

end Podmander.Controller.Supervisor;
