--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Podctl.Commands is

   procedure Set_Global_Switches
     (Config : in out CLIC.Subcommand.Switches_Configuration)
   is
      use CLIC.Subcommand;
   begin
      Define_Switch
        (Config,
         Output      => Controller_Value'Access,
         Long_Switch => "--controller=",
         Help        => "Controller endpoint (overrides config file)",
         Argument    => "ENDPOINT");
      Define_Switch
        (Config,
         Output      => Token_Value'Access,
         Long_Switch => "--token=",
         Help        =>
           "Join token for authentication (overrides config file)",
         Argument    => "TOKEN");
   end Set_Global_Switches;

end Podmander.Podctl.Commands;
