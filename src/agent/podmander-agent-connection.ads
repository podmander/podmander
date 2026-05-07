--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Connection state machine for the agent. Owns the CURVE socket
--  lifecycle, registration/heartbeat dispatch, and inbound-message
--  decoding. The parent package keeps only the Initialize/Run/Stop
--  lifecycle and delegates per-tick work to Step.

package Podmander.Agent.Connection is

   --  Advance the connection state machine by one tick. Reads
   --  Self.State, performs the work for that state, and may mutate
   --  Self.State (and other Self fields such as Socket and Backoff)
   --  as a side effect.
   procedure Step (Self : in out Agent_Instance);

end Podmander.Agent.Connection;
