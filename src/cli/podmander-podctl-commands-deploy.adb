--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNAT.Strings;
with Podmander.Podctl.Config;
with Podmander.Podctl.Deploy;

package body Podmander.Podctl.Commands.Deploy is

   use Ada.Strings.Unbounded;

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
      --  Rename avoids ambiguity between the package name "Deploy" and
      --  Podmander.Podctl.Deploy.Submit.
      package D renames Podmander.Podctl.Deploy;
      use type D.Deploy_Outcome;
      use type GNAT.Strings.String_Access;
   begin
      if Args.Is_Empty then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "Error: path argument required");
         GNAT.OS_Lib.OS_Exit (1);
      end if;

      declare
         Cfg_Result : constant Podmander.Podctl.Config.Load_Result :=
           Podmander.Podctl.Config.Load
             (Controller_Override =>
                (if Commands.Controller_Value /= null
                 then Commands.Controller_Value.all
                 else ""),
              Token_Override =>
                (if Commands.Token_Value /= null
                 then Commands.Token_Value.all
                 else ""));
      begin
         if not Cfg_Result.Success then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Error: " & To_String (Cfg_Result.Message));
            GNAT.OS_Lib.OS_Exit (1);
         end if;

         declare
            Result : constant D.Deploy_Result :=
              D.Submit
                (TOML_Path => Args.First_Element,
                 Cfg       => Cfg_Result.Value);
         begin
            if Result.Outcome = D.Accepted then
               Ada.Text_IO.Put_Line (To_String (Result.Message));
            else
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "Error: " & To_String (Result.Message));
               GNAT.OS_Lib.OS_Exit (D.Exit_Code_For (Result.Outcome));
            end if;
         end;
      end;
   end Execute;

end Podmander.Podctl.Commands.Deploy;
