--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  ISO 8601 timestamp conversion utilities for SQLite storage.
--  SQLite stores timestamps as TEXT; these functions convert between
--  Ada.Calendar.Time and the ISO 8601 format used in the database.

with Ada.Calendar;

package Podmander.Database.Time_Utils is

   function Time_To_ISO8601 (T : Ada.Calendar.Time) return String;
   -- Convert an Ada.Calendar.Time to ISO 8601 UTC string.
   -- Format: YYYY-MM-DDTHH:MM:SSZ.

   function ISO8601_To_Time (S : String) return Ada.Calendar.Time;
   -- Parse ISO 8601 UTC string back to Ada.Calendar.Time.
   -- Expects format YYYY-MM-DDTHH:MM:SSZ.

end Podmander.Database.Time_Utils;
