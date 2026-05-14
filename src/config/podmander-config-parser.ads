--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package Podmander.Config.Parser is

   type Parse_Result (Success : Boolean) is record
      case Success is
         when True  => Config : Service_Definition;
         when False => Message : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   function Parse (Path : String) return Parse_Result;
   --  Reads TOML file at Path, returns parsed config or error

   function Validate (Config : Service_Definition) return Parse_Result;
   --  Returns Success with config if valid, or Failure with error message

end Podmander.Config.Parser;
