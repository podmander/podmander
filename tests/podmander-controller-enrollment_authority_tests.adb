--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Behavioral tests for Podmander.Controller.Enrollment_Authority.
--  Real DB connections (":memory:") and real certificate I/O; no mocks.

with Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Cases;
with CZMQ.Certificates;
with Podmander.Controller.Enrollment_Authority;
with Podmander.Database;
with Podmander.Enrollment;

package body Podmander.Controller.Enrollment_Authority_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package EA renames Podmander.Controller.Enrollment_Authority;
   package DB renames Podmander.Database;

   Tmp_Cert_Path : constant String := "/tmp/podmander-ea-test.crt";

   type EA_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : EA_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Enrollment_Authority"));

   overriding
   procedure Register_Tests (T : in out EA_Test);

   --  Test 1: Bootstrap_Certificate generates a valid cert when file absent.
   procedure Test_Bootstrap_Certificate_Generates_When_Absent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cert : CZMQ.Certificates.Certificate;
   begin
      EA.Bootstrap_Certificate (Cert, "/tmp/podmander-ea-test-absent.crt");
      Assert (Cert.Is_Valid, "Bootstrap must yield a valid certificate");
   end Test_Bootstrap_Certificate_Generates_When_Absent;

   --  Test 2: Bootstrap_Certificate loads a cert that was previously saved.
   procedure Test_Bootstrap_Certificate_Loads_When_Present
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Original : CZMQ.Certificates.Certificate;
      Loaded   : CZMQ.Certificates.Certificate;
   begin
      EA.Bootstrap_Certificate (Original, Tmp_Cert_Path);
      declare
         Original_Key : constant String := Original.Public_Key;
      begin
         EA.Bootstrap_Certificate (Loaded, Tmp_Cert_Path);
         Assert (Loaded.Is_Valid, "Loaded certificate must be valid");
         Assert
           (Loaded.Public_Key = Original_Key,
            "Loaded public key must match the originally generated one");
      end;
   end Test_Bootstrap_Certificate_Loads_When_Present;

   --  Test 3: Bootstrap_Secret generates and persists when secret is absent.
   procedure Test_Bootstrap_Secret_Generates_When_Absent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
      Config : Podmander.Enrollment.Enrollment_Config;
   begin
      EA.Bootstrap_Secret (Handle, Config);
      Assert
        (Podmander.Enrollment.Get_Secret (Config) /= "",
         "Bootstrap must produce a non-empty secret");

      --  Re-call on the same connection; same secret must be loaded.
      declare
         Config2 : Podmander.Enrollment.Enrollment_Config;
      begin
         EA.Bootstrap_Secret (Handle, Config2);
         Assert
           (Podmander.Enrollment.Get_Secret (Config2)
            = Podmander.Enrollment.Get_Secret (Config),
            "Second call must load the persisted secret, not mint a new one");
      end;
   end Test_Bootstrap_Secret_Generates_When_Absent;

   --  Test 4: Bootstrap_Secret loads a secret that was seeded in the DB.
   procedure Test_Bootstrap_Secret_Loads_When_Present
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Handle : DB.DB_Handle := DB.Open (":memory:");
      Config : Podmander.Enrollment.Enrollment_Config;
   begin
      DB.Set_Setting (Handle, "registration_secret", "mySecret");
      EA.Bootstrap_Secret (Handle, Config);
      Assert
        (Podmander.Enrollment.Get_Secret (Config) = "mySecret",
         "Bootstrap must load the pre-seeded secret from the DB");
   end Test_Bootstrap_Secret_Loads_When_Present;

   --  Test 5: Get_Public_Key returns a non-empty string for a valid cert.
   procedure Test_Get_Public_Key_Valid_Cert
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cert : CZMQ.Certificates.Certificate;
   begin
      Cert.Generate;
      Assert
        (EA.Get_Public_Key (Cert) /= "",
         "Get_Public_Key must return a non-empty key for a valid certificate");
   end Test_Get_Public_Key_Valid_Cert;

   --  Test 6: Get_Public_Key returns "" for an uninitialized cert.
   procedure Test_Get_Public_Key_Invalid_Cert
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cert : CZMQ.Certificates.Certificate;
   begin
      Assert
        (EA.Get_Public_Key (Cert) = "",
         "Get_Public_Key must return empty string for an invalid certificate");
   end Test_Get_Public_Key_Invalid_Cert;

   --  Test 7: Generate_Join_Token produces a token parseable by Parse_Join_Token
   --  and the embedded public key matches the certificate's.
   procedure Test_Generate_Join_Token_Is_Parseable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cert   : CZMQ.Certificates.Certificate;
      Config : Podmander.Enrollment.Enrollment_Config;
      Token  : Unbounded_String;
   begin
      Cert.Generate;
      Podmander.Enrollment.Ensure_Secret (Config);
      EA.Generate_Join_Token (Cert, Config, Token);
      declare
         Parsed : constant Podmander.Enrollment.Parsed_Token :=
           Podmander.Enrollment.Parse_Join_Token (To_String (Token));
      begin
         Assert
           (To_String (Parsed.Public_Key) = EA.Get_Public_Key (Cert),
            "Token public key must match the certificate's public key");
      end;
   end Test_Generate_Join_Token_Is_Parseable;

   --  Test 8: Authorize returns True when the secret matches.
   procedure Test_Authorize_Matching_Secret
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : Podmander.Enrollment.Enrollment_Config;
   begin
      Podmander.Enrollment.Set_Secret (Config, "correct-secret");
      Assert
        (EA.Authorize (Config, "correct-secret"),
         "Authorize must return True when the secret matches");
   end Test_Authorize_Matching_Secret;

   --  Test 9: Authorize returns False when the secret does not match.
   procedure Test_Authorize_Wrong_Secret
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : Podmander.Enrollment.Enrollment_Config;
   begin
      Podmander.Enrollment.Set_Secret (Config, "correct-secret");
      Assert
        (not EA.Authorize (Config, "wrong-secret"),
         "Authorize must return False when the secret does not match");
   end Test_Authorize_Wrong_Secret;

   overriding
   procedure Register_Tests (T : in out EA_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Bootstrap_Certificate_Generates_When_Absent'Access,
         "Bootstrap_Certificate generates when cert file is absent");
      Register_Routine
        (T,
         Test_Bootstrap_Certificate_Loads_When_Present'Access,
         "Bootstrap_Certificate loads when cert file is present");
      Register_Routine
        (T,
         Test_Bootstrap_Secret_Generates_When_Absent'Access,
         "Bootstrap_Secret generates and persists when secret is absent");
      Register_Routine
        (T,
         Test_Bootstrap_Secret_Loads_When_Present'Access,
         "Bootstrap_Secret loads when secret is present in DB");
      Register_Routine
        (T,
         Test_Get_Public_Key_Valid_Cert'Access,
         "Get_Public_Key returns non-empty string for a valid certificate");
      Register_Routine
        (T,
         Test_Get_Public_Key_Invalid_Cert'Access,
         "Get_Public_Key returns empty string for an invalid certificate");
      Register_Routine
        (T,
         Test_Generate_Join_Token_Is_Parseable'Access,
         "Generate_Join_Token produces a parseable token with matching key");
      Register_Routine
        (T,
         Test_Authorize_Matching_Secret'Access,
         "Authorize returns True for matching secret");
      Register_Routine
        (T,
         Test_Authorize_Wrong_Secret'Access,
         "Authorize returns False for wrong secret");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased EA_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Enrollment_Authority_Tests;
