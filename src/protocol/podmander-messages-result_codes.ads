--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package Podmander.Messages.Result_Codes is

   type Result_Code is
     (Ok,              --  Operation succeeded
      Failed,           --  Operation failed (permanent, don't retry)
      Unavailable,      --  Target not reachable (transient, retry)
      Invalid_Argument, --  Bad input from controller
      Internal);        --  Agent-side bug / unexpected state

   function Encode_Code (Code : Result_Code) return String;
   -- Returns the wire representation: "OK", "FAILED", etc.

   function Decode_Code (S : String) return Result_Code;
   -- Raises Decode_Error for unknown strings.

end Podmander.Messages.Result_Codes;
