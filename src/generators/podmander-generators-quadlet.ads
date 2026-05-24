--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Config;

package Podmander.Generators.Quadlet is

   use Podmander.Config;

   -- Render a Service_Definition as a Quadlet .container file string.
   -- Generates [Unit], [Container], and [Install] sections.
   function Render (Service : Service_Definition) return String;

   -- Write a rendered Quadlet .container file to disk.
   -- Creates Output_Dir if it does not exist.
   procedure Write_File
     (Service      : Service_Definition;
      Output_Dir   : String;
      Service_Name : String);

end Podmander.Generators.Quadlet;
