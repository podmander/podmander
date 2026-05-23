--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Strings.Unbounded;
with Podmander.Enrollment;

package body Podmander.Enrollment_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   type Enrollment_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Enrollment_Test) return AUnit.Message_String
   is (AUnit.Format ("Enrollment Token Parser"));

   overriding
   procedure Register_Tests (T : in out Enrollment_Test);

   -- A 40-character placeholder that mimics a Z85-encoded CURVE public key.
   -- Generate_Join_Token does not validate Z85, so any 40-char string works.
   Sample_Public_Key : constant String := "0123456789012345678901234567890123456789";

   -- Test: a freshly generated token round-trips through Parse_Join_Token,
   -- reproducing both the public key embedded by the controller and the
   -- secret stored in Enrollment_Config.
   procedure Test_Roundtrip_Recovers_Public_Key_And_Secret (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : Podmander.Enrollment.Enrollment_Config;
      Token  : Unbounded_String;
   begin
      Podmander.Enrollment.Generate_Join_Token (Public_Key => Sample_Public_Key, Config => Config, Token => Token);

      declare
         Parsed : constant Podmander.Enrollment.Parsed_Token :=
           Podmander.Enrollment.Parse_Join_Token (To_String (Token));
      begin
         Assert
           (To_String (Parsed.Public_Key) = Sample_Public_Key,
            "Parsed public key does not match the one embedded by Generate");
         Assert
           (To_String (Parsed.Secret) = Podmander.Enrollment.Get_Secret (Config),
            "Parsed secret does not match the secret stored in Config");
      end;
   end Test_Roundtrip_Recovers_Public_Key_And_Secret;

   -- Test: a token without the PTKN- prefix is rejected.
   procedure Test_Wrong_Prefix_Raises (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Bogus : constant String := "XXXX-" & Sample_Public_Key & "-" & "00000000000000000000000000000000";
   begin
      declare
         Ignored : constant Podmander.Enrollment.Parsed_Token := Podmander.Enrollment.Parse_Join_Token (Bogus);
      begin
         Assert (False, "Expected Parse_Error for wrong prefix");
         pragma Unreferenced (Ignored);
      end;
   exception
      when Podmander.Enrollment.Parse_Error =>
         null;
   end Test_Wrong_Prefix_Raises;

   -- Test: a token that does not span the full prefix+key+sep+secret length
   -- is rejected before any indexing occurs.
   procedure Test_Too_Short_Raises (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         Ignored : constant Podmander.Enrollment.Parsed_Token := Podmander.Enrollment.Parse_Join_Token ("PTKN-short");
      begin
         Assert (False, "Expected Parse_Error for short token");
         pragma Unreferenced (Ignored);
      end;
   exception
      when Podmander.Enrollment.Parse_Error =>
         null;
   end Test_Too_Short_Raises;

   -- Test: a fully-empty token is rejected.
   procedure Test_Empty_Raises (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         Ignored : constant Podmander.Enrollment.Parsed_Token := Podmander.Enrollment.Parse_Join_Token ("");
      begin
         Assert (False, "Expected Parse_Error for empty token");
         pragma Unreferenced (Ignored);
      end;
   exception
      when Podmander.Enrollment.Parse_Error =>
         null;
   end Test_Empty_Raises;

   -- Test: calling Generate_Join_Token twice reuses the same secret
   -- when one is already set in the config.
   procedure Test_Generate_Join_Token_Reuses_Secret (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : Podmander.Enrollment.Enrollment_Config;
      Token1 : Unbounded_String;
      Token2 : Unbounded_String;
   begin
      Podmander.Enrollment.Generate_Join_Token (Public_Key => Sample_Public_Key, Config => Config, Token => Token1);
      Podmander.Enrollment.Generate_Join_Token (Public_Key => Sample_Public_Key, Config => Config, Token => Token2);
      Assert
        (To_String (Token1) = To_String (Token2),
         "Second Generate_Join_Token should produce the same token " & "when secret is already set");
   end Test_Generate_Join_Token_Reuses_Secret;

   overriding
   procedure Register_Tests (T : in out Enrollment_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Roundtrip_Recovers_Public_Key_And_Secret'Access,
         "Generate then Parse recovers both halves of the token");
      Register_Routine (T, Test_Wrong_Prefix_Raises'Access, "Parse_Join_Token rejects wrong prefix");
      Register_Routine (T, Test_Too_Short_Raises'Access, "Parse_Join_Token rejects token shorter than expected");
      Register_Routine (T, Test_Empty_Raises'Access, "Parse_Join_Token rejects empty token");
      Register_Routine (T, Test_Generate_Join_Token_Reuses_Secret'Access, "Generate_Join_Token reuses existing secret");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Enrollment_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Enrollment_Tests;
