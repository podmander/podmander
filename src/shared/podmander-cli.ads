--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Minimal CLI argument parsing for --key=value style arguments.

package Podmander.CLI is

   --  Look up a --key=value argument. Returns Default if not found.
   function Get (Key : String; Default : String := "") return String;

   --  Look up a --key=value argument and parse as Duration (seconds).
   --  Returns Default if not found or not a valid number.
   function Get_Duration (Key : String; Default : Duration) return Duration;

   --  Print a usage message and set Program_Error flag.
   procedure Print_Usage (Usage : String);

end Podmander.CLI;
