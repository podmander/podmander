--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

--  Shutdown detection via CZMQ's built-in signal handling.
--  CZMQ installs its own SIGINT/SIGTERM handler that sets
--  zsys_interrupted, which causes zpoller_wait to return early.

with Interfaces.C;

package Podmander.Shutdown is

   --  Check whether a shutdown signal has been received.
   function Requested return Boolean;

private

   Zsys_Interrupted : Interfaces.C.int
     with Import, Convention => C, External_Name => "zsys_interrupted";

end Podmander.Shutdown;
