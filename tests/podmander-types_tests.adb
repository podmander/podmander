--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Config;
with Podmander.Types;

package body Podmander.Types_Tests is

   use AUnit.Assertions;

   type Types_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Types_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander Domain Types"));

   overriding
   procedure Register_Tests (T : in out Types_Test);

   procedure Test_Node_Id_Type_Allows_Only_Nonnegative_Ids
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Negative_Id : constant Integer := Integer'Value ("-1");
   begin
      declare
         Ignored : constant Podmander.Types.Node_Id_Type :=
           Podmander.Types.Node_Id_Type (Negative_Id);
         pragma Unreferenced (Ignored);
      begin
         Assert (False, "Node_Id_Type should reject negative values");
      end;
   exception
      when Constraint_Error =>
         null;
   end Test_Node_Id_Type_Allows_Only_Nonnegative_Ids;

   procedure Test_Port_Number_Uses_Valid_Port_Range
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Podmander.Config.Port_Number'First = Podmander.Config.MIN_PORT,
         "Port_Number should start at the configured minimum port");
      Assert
        (Podmander.Config.Port_Number'Last = Podmander.Config.MAX_PORT,
         "Port_Number should end at the configured maximum port");
   end Test_Port_Number_Uses_Valid_Port_Range;

   overriding
   procedure Register_Tests (T : in out Types_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Node_Id_Type_Allows_Only_Nonnegative_Ids'Access,
         "Node IDs cannot represent negative values");
      Register_Routine
        (T,
         Test_Port_Number_Uses_Valid_Port_Range'Access,
         "Port numbers are constrained to the valid port range");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Types_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Types_Tests;
