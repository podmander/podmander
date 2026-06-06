--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AAA.Strings;
with CLIC.Subcommand;

package Podmander.Podctl.Commands.Deploy is

   type Command is new CLIC.Subcommand.Command with null record;

   overriding
   function Name (Cmd : Command) return CLIC.Subcommand.Identifier;

   overriding
   function Short_Description (Cmd : Command) return String;

   overriding
   function Long_Description (Cmd : Command) return AAA.Strings.Vector;

   overriding
   function Switch_Parsing
     (Cmd : Command) return CLIC.Subcommand.Switch_Parsing_Kind;

   overriding
   function Usage_Custom_Parameters (Cmd : Command) return String;

   overriding
   procedure Execute (Cmd : in out Command; Args : AAA.Strings.Vector);

end Podmander.Podctl.Commands.Deploy;
