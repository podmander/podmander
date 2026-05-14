--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Strings.Unbounded;
with Podmander.Config;

package body Podmander.Config_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   type Config_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name
     (T : Config_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander Config Types and Parser"));

   overriding procedure Register_Tests (T : in out Config_Test);

   --  Test constructing a Service_Definition with valid fields
   procedure Test_Service_Definition_Construction
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others =>
                            (Key   => Null_Unbounded_String,
                             Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others =>
                            (Host      => 1,
                             Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others =>
                            (Host      => Null_Unbounded_String,
                             Container => Null_Unbounded_String)],
         Volumes_Count => 0);
   begin
      Assert (To_String (Config.Image) = "nginx:latest",
              "Image should be 'nginx:latest'");
   end Test_Service_Definition_Construction;

   --  Test constructing a Port_Mapping with valid fields
   procedure Test_Port_Mapping_Construction
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Mapping : constant Podmander.Config.Port_Mapping :=
        (Host => 8080, Container => 80);
   begin
      Assert (Mapping.Host = 8080,
              "Port_Mapping Host should be 8080");
      Assert (Mapping.Container = 80,
              "Port_Mapping Container should be 80");
   end Test_Port_Mapping_Construction;

   --  Register all test routines
   overriding procedure Register_Tests (T : in out Config_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Service_Definition_Construction'Access,
         "Constructing a Service_Definition with valid fields");
      Register_Routine
        (T, Test_Port_Mapping_Construction'Access,
         "Constructing a Port_Mapping with valid fields");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Config_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Config_Tests;
