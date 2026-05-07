--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Messages.Result_Codes;

package Podmander.Agent.Host_Command.Result_Mapping is

   package RC renames Podmander.Messages.Result_Codes;

   function To_Result_Code (Result : Command_Result) return RC.Result_Code;
   --  Map a host-command outcome onto the protocol's Result_Code vocabulary.
   --
   --  Bucketing is intentionally coarse:
   --    Exited (0)        -> Ok
   --    Exited (non-zero) -> Failed       (permanent; do not retry)
   --    Error             -> Unavailable  (binary missing or spawn failed)
   --    Crashed           -> Internal     (signal-induced crash)
   --    Terminated        -> Internal     (signal-induced termination)
   --
   --  Errno detail and signal numbers are deliberately collapsed into the
   --  five-code protocol vocabulary. Refine when controller retry behaviour
   --  needs the distinction (e.g., separating ENOENT from EACCES, or routing
   --  SIGKILL to Unavailable for OOM-induced termination).

end Podmander.Agent.Host_Command.Result_Mapping;
