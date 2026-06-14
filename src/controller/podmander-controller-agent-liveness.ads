--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  The Liveness Monitor drives the agent state machine (Registered ->
--  Unresponsive -> Lost) based on heartbeat recency. Check_Timeouts runs each
--  poll tick; Recover resets all non-Lost agents to Unresponsive on startup so
--  each must heartbeat again to prove liveness after a controller restart.

with Podmander.Database;

package Podmander.Controller.Agent.Liveness is

   procedure Check_Timeouts
     (DB : in out Podmander.Database.DB_Handle; Agent_Timeout : Duration);
   --  One pass over all agents: Registered agents idle >= 2x Agent_Timeout
   --  become Unresponsive; any non-Lost agent idle >= 3x Agent_Timeout
   --  becomes Lost. Called each poll tick.

   procedure Recover (DB : in out Podmander.Database.DB_Handle);
   --  Startup convergence: reset every agent not already Lost to Unresponsive,
   --  so each must heartbeat again to prove liveness after a controller
   --  restart. Agents that were Lost before the restart are preserved as Lost
   --  because they have already been declared disconnected.

end Podmander.Controller.Agent.Liveness;
