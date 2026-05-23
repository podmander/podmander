--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar.Formatting;

package body Podmander.Database.Time_Utils is

   function Time_To_ISO8601 (T : Ada.Calendar.Time) return String is
      Raw : constant String := Ada.Calendar.Formatting.Image (T);
   begin
      return Raw (1 .. 10) & "T" & Raw (12 .. 19) & "Z";
   end Time_To_ISO8601;

   function ISO8601_To_Time (S : String) return Ada.Calendar.Time is
      Fixed : String (1 .. 19) := S (S'First .. S'First + 18);
   begin
      Fixed (11) := ' ';
      return Ada.Calendar.Formatting.Value (Fixed);
   end ISO8601_To_Time;

end Podmander.Database.Time_Utils;
