--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Generators.Caddy;

package body Podmander.Generators.Caddy_Tests is

   use AUnit.Assertions;
   use Podmander.Generators.Caddy;

   type Caddy_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Caddy_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Generators.Caddy"));

   overriding
   procedure Register_Tests (T : in out Caddy_Test);

   procedure Test_Render_Single_Ingress
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Expected : constant String :=
        "example.com {"
        & ASCII.LF
        & "    reverse_proxy 127.0.0.1:8080"
        & ASCII.LF
        & "}"
        & ASCII.LF;
   begin
      Assert
        (Render ("example.com", 8080) = Expected,
         "Caddy generator must render exact single-ingress output");
   end Test_Render_Single_Ingress;

   overriding
   procedure Register_Tests (T : in out Caddy_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Render_Single_Ingress'Access,
         "render exact Caddy reverse proxy output");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Caddy_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Generators.Caddy_Tests;
