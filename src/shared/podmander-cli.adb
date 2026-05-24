--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Command_Line;
with Podmander.Logging;

package body Podmander.CLI is

   function Get (Key : String; Default : String := "") return String is
      Equal_Prefix : constant String := "--" & Key & "=";
      Name_Prefix  : constant String := "--" & Key;
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if Arg'Length > Equal_Prefix'Length
              and then Arg (Arg'First .. Arg'First + Equal_Prefix'Length - 1)
                       = Equal_Prefix
            then
               return Arg (Arg'First + Equal_Prefix'Length .. Arg'Last);
            end if;

            if Arg = Name_Prefix and then I < Ada.Command_Line.Argument_Count
            then
               return Ada.Command_Line.Argument (I + 1);
            end if;
         end;
      end loop;
      return Default;
   end Get;

   function Get_Duration (Key : String; Default : Duration) return Duration is
      Value : constant String := Get (Key);
   begin
      if Value = "" then
         return Default;
      end if;
      return Duration'Value (Value);
   exception
      when Constraint_Error =>
         Podmander.Logging.Warning
           ("cli",
            "Invalid value for --"
            & Key
            & ", using default"
            & Duration'Image (Default));
         return Default;
   end Get_Duration;

   procedure Print_Usage (Usage : String) is
   begin
      Ada.Command_Line.Set_Exit_Status (1);
      Podmander.Logging.Critical ("cli", "Usage: " & Usage);
   end Print_Usage;

end Podmander.CLI;
