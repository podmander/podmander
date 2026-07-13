--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar.Formatting;

package body Podmander.Database.Time_Utils is

   ISO8601_Length : constant := 20;

   function Is_Digit (C : Character) return Boolean
   is (C in '0' .. '9');

   function Has_ISO8601_Shape (S : String) return Boolean is
   begin
      return
        S'Length = ISO8601_Length
        and then Is_Digit (S (S'First))
        and then Is_Digit (S (S'First + 1))
        and then Is_Digit (S (S'First + 2))
        and then Is_Digit (S (S'First + 3))
        and then S (S'First + 4) = '-'
        and then Is_Digit (S (S'First + 5))
        and then Is_Digit (S (S'First + 6))
        and then S (S'First + 7) = '-'
        and then Is_Digit (S (S'First + 8))
        and then Is_Digit (S (S'First + 9))
        and then S (S'First + 10) = 'T'
        and then Is_Digit (S (S'First + 11))
        and then Is_Digit (S (S'First + 12))
        and then S (S'First + 13) = ':'
        and then Is_Digit (S (S'First + 14))
        and then Is_Digit (S (S'First + 15))
        and then S (S'First + 16) = ':'
        and then Is_Digit (S (S'First + 17))
        and then Is_Digit (S (S'First + 18))
        and then S (S'First + 19) = 'Z';
   end Has_ISO8601_Shape;

   function Time_To_ISO8601 (T : Ada.Calendar.Time) return String is
      Raw : constant String := Ada.Calendar.Formatting.Image (T);
   begin
      return Raw (1 .. 10) & "T" & Raw (12 .. 19) & "Z";
   end Time_To_ISO8601;

   function ISO8601_To_Time (S : String) return Ada.Calendar.Time is
      Fixed : String (1 .. 19);
   begin
      if not Has_ISO8601_Shape (S) then
         raise Constraint_Error
           with "expected ISO8601 timestamp in YYYY-MM-DDTHH:MM:SSZ format";
      end if;

      Fixed := S (S'First .. S'First + 18);
      Fixed (11) := ' ';
      return Ada.Calendar.Formatting.Value (Fixed);
   end ISO8601_To_Time;

end Podmander.Database.Time_Utils;
