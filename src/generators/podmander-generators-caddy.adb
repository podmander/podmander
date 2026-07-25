--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Generators.Caddy is

   ------------
   -- Render  --
   ------------

   function Render
     (Host : String; Port : Podmander.Config.Port_Number) return String
   is
      Port_Text : constant String := Podmander.Config.Port_Number'Image (Port);
   begin
      return Host & " {" & ASCII.LF
        & "    reverse_proxy 127.0.0.1:"
        & Port_Text (Port_Text'First + 1 .. Port_Text'Last)
        & ASCII.LF
        & "}" & ASCII.LF;
   end Render;

end Podmander.Generators.Caddy;
