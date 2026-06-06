--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.Podctl.Config;

package Podmander.Podctl.Deploy is

   use Ada.Strings.Unbounded;

   type Deploy_Outcome is
     (Accepted,     --  Controller accepted the stack
      Token_Error,  --  Join token is malformed
      File_Error,   --  TOML file missing or empty
      Timeout,      --  Controller did not reply in time
      Rejected);    --  Controller rejected the submission

   type Deploy_Result is record
      Outcome : Deploy_Outcome;
      Message : Unbounded_String;
   end record;

   type File_Check is (Ok, Not_Found, Empty);

   function Submit
     (TOML_Path : String;
      Cfg       : Podmander.Podctl.Config.Connection_Config)
      return Deploy_Result;

   --  Exposed for testing: check file existence and non-emptiness.
   function Check_TOML_File (Path : String) return File_Check;

   --  Exposed for testing: map outcome to a process exit code.
   function Exit_Code_For (Outcome : Deploy_Outcome) return Integer;

end Podmander.Podctl.Deploy;
