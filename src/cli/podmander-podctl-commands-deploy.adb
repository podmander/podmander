--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Text_IO;
with GNAT.OS_Lib;

package body Podmander.Podctl.Commands.Deploy is

   overriding
   function Name (Cmd : Command) return CLIC.Subcommand.Identifier is
      pragma Unreferenced (Cmd);
   begin
      return "deploy";
   end Name;

   overriding
   function Short_Description (Cmd : Command) return String is
      pragma Unreferenced (Cmd);
   begin
      return "Submit a service stack TOML to the controller";
   end Short_Description;

   overriding
   function Long_Description (Cmd : Command) return AAA.Strings.Vector is
      pragma Unreferenced (Cmd);
   begin
      return
        AAA.Strings.Empty_Vector.Append
          ("Submit a service stack TOML file to the controller.")
          .Append
             ("The controller parses, registers, and schedules the stack"
              & " asynchronously.");
   end Long_Description;

   overriding
   function Switch_Parsing
     (Cmd : Command) return CLIC.Subcommand.Switch_Parsing_Kind
   is
      pragma Unreferenced (Cmd);
   begin
      return CLIC.Subcommand.Parse_All;
   end Switch_Parsing;

   overriding
   function Usage_Custom_Parameters (Cmd : Command) return String is
      pragma Unreferenced (Cmd);
   begin
      return "<path>";
   end Usage_Custom_Parameters;

   overriding
   procedure Execute (Cmd : in out Command; Args : AAA.Strings.Vector) is
      pragma Unreferenced (Cmd);
   begin
      if Args.Is_Empty then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "Error: path argument required");
         GNAT.OS_Lib.OS_Exit (1);
      end if;
      Ada.Text_IO.Put_Line
        ("deploy " & Args.First_Element & " (not yet implemented)");
   end Execute;

end Podmander.Podctl.Commands.Deploy;
