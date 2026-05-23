--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Connection state machine for the agent. Uses the CZMQ Open/Close
--  API to manage the CURVE certificate and ZeroMQ socket as fields
--  on Agent_Instance. Each reconnect cycle calls Close (idempotent)
--  then Open_Dealer/Generate to re-establish the connection. The
--  Limited_Controlled finalizers release resources on shutdown.

package Podmander.Agent.Connection is

   -- Run one full connection attempt: connect -> enrol -> connected
   -- loop. Returns when the cycle ends (registration timeout,
   -- decode error, connection lost, or shutdown). On exit Self.State
   -- reflects whether the cycle succeeded (left in Connected only on
   -- shutdown) or failed (Disconnected). Self.Backoff is updated on
   -- registration timeout.
   procedure Run_Cycle (Self : in out Agent_Instance);

end Podmander.Agent.Connection;
