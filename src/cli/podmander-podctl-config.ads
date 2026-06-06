--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;

package Podmander.Podctl.Config is

   use Ada.Strings.Unbounded;

   Default_Controller : constant String := "tcp://localhost:5555";

   type Connection_Config is record
      Controller : Unbounded_String;
      Token      : Unbounded_String;
   end record;

   type Load_Result (Success : Boolean) is record
      case Success is
         when True =>
            Value : Connection_Config;

         when False =>
            Message : Unbounded_String;
      end case;
   end record;

   --  Load connection config from file and flag overrides.
   --
   --  Config_File: path to TOML file; empty string resolves to
   --  ~/.config/podmander/podctl.toml. Missing file is not an error.
   --  Controller_Override / Token_Override: when non-empty, override
   --  the file value (flags beat file). Token is required; absent token
   --  returns a failure result.
   function Load
     (Config_File         : String := "";
      Controller_Override : String := "";
      Token_Override      : String := "") return Load_Result;

end Podmander.Podctl.Config;
