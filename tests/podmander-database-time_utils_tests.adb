--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Database.Time_Utils;

package body Podmander.Database.Time_Utils_Tests is

   use AUnit.Assertions;
   use type Ada.Calendar.Time;

   type Time_Utils_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Time_Utils_Test) return AUnit.Message_String
   is (AUnit.Format ("Database Time Utils"));

   overriding
   procedure Register_Tests (T : in out Time_Utils_Test);

   procedure Test_ISO8601_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      Original : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of
          (Year    => 2026,
           Month   => 7,
           Day     => 13,
           Seconds => 12.0 * 3_600.0 + 34.0 * 60.0 + 56.0);
      Encoded  : constant String :=
        Podmander.Database.Time_Utils.Time_To_ISO8601 (Original);
      Parsed   : constant Ada.Calendar.Time :=
        Podmander.Database.Time_Utils.ISO8601_To_Time (Encoded);
   begin
      Assert (Encoded'Length = 20, "ISO8601 image should use fixed length");
      Assert (Parsed = Original, "parsed time should match original time");
   end Test_ISO8601_Round_Trip;

   procedure Assert_Invalid_ISO8601 (Value : String) is
      Parsed : Ada.Calendar.Time;
      pragma Unreferenced (Parsed);
   begin
      Parsed := Podmander.Database.Time_Utils.ISO8601_To_Time (Value);
      Assert (False, "invalid ISO8601 value should raise Constraint_Error");
   exception
      when Constraint_Error =>
         null;
   end Assert_Invalid_ISO8601;

   procedure Test_ISO8601_Rejects_Invalid_Length
     (T : in out AUnit.Test_Cases.Test_Case'Class) is
   begin
      pragma Unreferenced (T);
      Assert_Invalid_ISO8601 ("2026-07-13T12:34:56");
      Assert_Invalid_ISO8601 ("2026-07-13T12:34:56Z-extra");
   end Test_ISO8601_Rejects_Invalid_Length;

   procedure Test_ISO8601_Rejects_Invalid_Shape
     (T : in out AUnit.Test_Cases.Test_Case'Class) is
   begin
      pragma Unreferenced (T);
      Assert_Invalid_ISO8601 ("2026/07/13T12:34:56Z");
      Assert_Invalid_ISO8601 ("2026-07-13 12:34:56Z");
      Assert_Invalid_ISO8601 ("2026-07-13T12:34:56+00:00");
      Assert_Invalid_ISO8601 ("2026-07-13T12:34:5xZ");
   end Test_ISO8601_Rejects_Invalid_Shape;

   overriding
   procedure Register_Tests (T : in out Time_Utils_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_ISO8601_Round_Trip'Access, "ISO8601 conversion round-trips");
      Register_Routine
        (T,
         Test_ISO8601_Rejects_Invalid_Length'Access,
         "ISO8601 parser rejects invalid lengths");
      Register_Routine
        (T,
         Test_ISO8601_Rejects_Invalid_Shape'Access,
         "ISO8601 parser rejects invalid shape");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Time_Utils_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Database.Time_Utils_Tests;
