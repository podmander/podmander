--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

with Ada.Command_Line;
with Ada.Text_IO;

package body Podmander.CLI is

   function Get
     (Key     : String;
      Default : String := "") return String
   is
      Prefix : constant String := "--" & Key & "=";
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if Arg'Length > Prefix'Length
              and then Arg (Arg'First .. Arg'First + Prefix'Length - 1)
                       = Prefix
            then
               return Arg (Arg'First + Prefix'Length .. Arg'Last);
            end if;
         end;
      end loop;
      return Default;
   end Get;

   function Get_Duration
     (Key     : String;
      Default : Duration) return Duration
   is
      Value : constant String := Get (Key);
   begin
      if Value = "" then
         return Default;
      end if;
      return Duration'Value (Value);
   exception
      when Constraint_Error =>
         Ada.Text_IO.Put_Line
           ("WARNING: Invalid value for --" & Key
            & ", using default" & Duration'Image (Default));
         return Default;
   end Get_Duration;

   procedure Print_Usage (Usage : String) is
   begin
      Ada.Text_IO.Put_Line ("Usage: " & Usage);
   end Print_Usage;

end Podmander.CLI;
