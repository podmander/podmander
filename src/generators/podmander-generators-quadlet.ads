--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Config;

package Podmander.Generators.Quadlet is

   use Podmander.Config;

   --  Render a Service_Definition as a Quadlet .container file string.
   --  Currently generates only the [Container] section.
   function Render (Service : Service_Definition) return String;

end Podmander.Generators.Quadlet;
