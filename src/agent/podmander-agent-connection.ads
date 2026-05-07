--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Connection state machine for the agent. Owns one CURVE certificate
--  and ZeroMQ socket per connection cycle as scope-bound locals; the
--  Limited_Controlled CZMQ types finalize automatically when the
--  cycle ends, releasing the underlying resources without explicit
--  deallocation. The parent package's Run loop calls Run_Cycle for
--  each (re)connection attempt and applies backoff between cycles.

package Podmander.Agent.Connection is

   --  Run one full connection attempt: connect → enrol → connected
   --  loop. Returns when the cycle ends (registration timeout,
   --  decode error, connection lost, or shutdown). On exit Self.State
   --  reflects whether the cycle succeeded (left in Connected only on
   --  shutdown) or failed (Disconnected). Self.Backoff is updated on
   --  registration timeout.
   procedure Run_Cycle (Self : in out Agent_Instance);

end Podmander.Agent.Connection;
