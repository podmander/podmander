--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Config;

package Podmander.Generators.Caddy is

   -- Render a single ingress route as a Caddyfile string.
   function Render
     (Host : String; Port : Podmander.Config.Port_Number) return String;

end Podmander.Generators.Caddy;
