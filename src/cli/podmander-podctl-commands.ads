--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Text_IO;
with CLIC.Subcommand;
with CLIC.Subcommand.Instance;
with CLIC.TTY;
with GNAT.OS_Lib;
with GNAT.Strings;

package Podmander.Podctl.Commands is

   --  Storage for global switch values populated by CLIC during parsing.
   Controller_Value : aliased GNAT.Strings.String_Access;
   Token_Value      : aliased GNAT.Strings.String_Access;

   procedure Set_Global_Switches
     (Config : in out CLIC.Subcommand.Switches_Configuration);

   package Instance is new
     CLIC.Subcommand.Instance
       (Main_Command_Name                 => "podctl",
        Version                           => "0.1.0",
        Set_Global_Switches               => Set_Global_Switches,
        Put                               => Ada.Text_IO.Put,
        Put_Line                          => Ada.Text_IO.Put_Line,
        Put_Error                         => Ada.Text_IO.Put_Line,
        Error_Exit                        => GNAT.OS_Lib.OS_Exit,
        TTY_Chapter                       => CLIC.TTY.Info,
        TTY_Description                   => CLIC.TTY.Description,
        TTY_Version                       => CLIC.TTY.Version,
        TTY_Underline                     => CLIC.TTY.Underline,
        TTY_Emph                          => CLIC.TTY.Emph,
        Global_Options_In_subcommand_help => True);

end Podmander.Podctl.Commands;
