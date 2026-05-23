--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Strings.Unbounded;
with Podmander.Config;
with Podmander.Config.Parser;

package body Podmander.Config_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   type Config_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Config_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander Config Types and Parser"));

   overriding
   procedure Register_Tests (T : in out Config_Test);

   --  Path helper for fixture files
   Fixture_Dir : constant String := "tests/fixtures/";

   function Fixture_Path (Name : String) return String
   is (Fixture_Dir & Name);

   --  Test constructing a Service_Definition with valid fields
   procedure Test_Service_Definition_Construction (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Name          => Null_Unbounded_String,
         Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others => (Key => Null_Unbounded_String, Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others => (Host => 1, Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others => (Host => Null_Unbounded_String, Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
   begin
      Assert (To_String (Config.Image) = "nginx:latest", "Image should be 'nginx:latest'");
   end Test_Service_Definition_Construction;

   --  Test constructing a Port_Mapping with valid fields
   procedure Test_Port_Mapping_Construction (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Mapping : constant Podmander.Config.Port_Mapping := (Host => 8080, Container => 80);
   begin
      Assert (Mapping.Host = 8080, "Port_Mapping Host should be 8080");
      Assert (Mapping.Container = 80, "Port_Mapping Container should be 80");
   end Test_Port_Mapping_Construction;

   --  Test parsing a valid TOML file
   procedure Test_Parse_Valid_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : constant Podmander.Config.Parser.Parse_Result :=
        Podmander.Config.Parser.Parse (Fixture_Path ("valid.toml"));
   begin
      Assert (Result.Success, "Parsing valid.toml should succeed");
      if Result.Success then
         Assert (To_String (Result.Config.Image) = "nginx:latest", "Image should be 'nginx:latest'");
         Assert (Result.Config.Ports_Count = 2, "Should have 2 port mappings");
         if Result.Config.Ports_Count >= 1 then
            Assert (Result.Config.Ports (1).Host = 80, "First port host should be 80");
            Assert (Result.Config.Ports (1).Container = 80, "First port container should be 80");
         end if;
         if Result.Config.Ports_Count >= 2 then
            Assert (Result.Config.Ports (2).Host = 443, "Second port host should be 443");
            Assert (Result.Config.Ports (2).Container = 443, "Second port container should be 443");
         end if;
         Assert (Result.Config.Volumes_Count = 2, "Should have 2 volume mappings");
         Assert (Result.Config.Env_Count = 2, "Should have 2 env entries");
      end if;
   end Test_Parse_Valid_File;

   --  Test parsing a TOML file with missing image field
   procedure Test_Parse_Missing_Image (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : constant Podmander.Config.Parser.Parse_Result :=
        Podmander.Config.Parser.Parse (Fixture_Path ("missing_image.toml"));
   begin
      Assert (not Result.Success, "Parsing missing_image.toml should fail");
   end Test_Parse_Missing_Image;

   --  Test parsing a file that doesn't exist
   procedure Test_Parse_Nonexistent_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : constant Podmander.Config.Parser.Parse_Result :=
        Podmander.Config.Parser.Parse ("/nonexistent/path/file.toml");
   begin
      Assert (not Result.Success, "Parsing nonexistent file should fail");
   end Test_Parse_Nonexistent_File;

   --  Test parsing TOML syntax error
   procedure Test_Parse_Invalid_Syntax (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : constant Podmander.Config.Parser.Parse_Result :=
        Podmander.Config.Parser.Parse (Fixture_Path ("invalid_syntax.toml"));
   begin
      Assert (not Result.Success, "Parsing invalid_syntax.toml should fail");
   end Test_Parse_Invalid_Syntax;

   --  Test valid config passes validation
   procedure Test_Valid_Config_Passes_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Name          => Null_Unbounded_String,
         Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others => (Key => Null_Unbounded_String, Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others => (Host => 1, Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others => (Host => Null_Unbounded_String, Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Result : constant Podmander.Config.Parser.Parse_Result := Podmander.Config.Parser.Validate (Config);
   begin
      Assert (Result.Success, "Valid config should pass validation");
   end Test_Valid_Config_Passes_Validation;

   --  Test empty image fails validation
   procedure Test_Empty_Image_Fails_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Name          => Null_Unbounded_String,
         Image         => Null_Unbounded_String,
         Env           => [others => (Key => Null_Unbounded_String, Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others => (Host => 1, Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others => (Host => Null_Unbounded_String, Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Result : constant Podmander.Config.Parser.Parse_Result := Podmander.Config.Parser.Validate (Config);
   begin
      Assert (not Result.Success, "Empty image should fail validation");
   end Test_Empty_Image_Fails_Validation;

   --  Test port out of range fails validation (65536)
   procedure Test_Port_Out_Of_Range_Fails_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Name          => Null_Unbounded_String,
         Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others => (Key => Null_Unbounded_String, Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [1 => (Host => 65536, Container => 80), others => (Host => 1, Container => 1)],
         Ports_Count   => 1,
         Volumes       => [others => (Host => Null_Unbounded_String, Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Result : constant Podmander.Config.Parser.Parse_Result := Podmander.Config.Parser.Validate (Config);
   begin
      Assert (not Result.Success, "Port host 65536 should fail validation");
   end Test_Port_Out_Of_Range_Fails_Validation;

   --  Test empty volume path fails validation
   procedure Test_Empty_Volume_Path_Fails_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Name          => Null_Unbounded_String,
         Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others => (Key => Null_Unbounded_String, Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others => (Host => 1, Container => 1)],
         Ports_Count   => 0,
         Volumes       =>
           [1      => (Host => Null_Unbounded_String, Container => To_Unbounded_String ("/data")),
            others => (Host => Null_Unbounded_String, Container => Null_Unbounded_String)],
         Volumes_Count => 1,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Result : constant Podmander.Config.Parser.Parse_Result := Podmander.Config.Parser.Validate (Config);
   begin
      Assert (not Result.Success, "Empty volume host path should fail validation");
   end Test_Empty_Volume_Path_Fails_Validation;

   --  Test that parser extracts service name from TOML section header
   procedure Test_Parse_Extracts_Service_Name (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : constant Podmander.Config.Parser.Parse_Result :=
        Podmander.Config.Parser.Parse (Fixture_Path ("valid.toml"));
   begin
      Assert (Result.Success, "Parsing valid.toml should succeed");
      if Result.Success then
         Assert (To_String (Result.Config.Name) = "web", "Service name should be 'web' from [service.web] header");
      end if;
   end Test_Parse_Extracts_Service_Name;

   --  Test constructing a Service_Definition with Name field
   procedure Test_Service_Definition_Name_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Name          => To_Unbounded_String ("myservice"),
         Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others => (Key => Null_Unbounded_String, Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others => (Host => 1, Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others => (Host => Null_Unbounded_String, Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
   begin
      Assert (To_String (Config.Name) = "myservice", "Name should be 'myservice'");
   end Test_Service_Definition_Name_Field;

   --  Test constructing a Service_Definition with Description field
   procedure Test_Service_Definition_Description_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Name          => Null_Unbounded_String,
         Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others => (Key => Null_Unbounded_String, Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others => (Host => 1, Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others => (Host => Null_Unbounded_String, Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => To_Unbounded_String ("My web app"),
         WantedBy      => Null_Unbounded_String);
   begin
      Assert (To_String (Config.Description) = "My web app", "Description should be 'My web app'");
   end Test_Service_Definition_Description_Field;

   --  Test constructing a Service_Definition with WantedBy field
   procedure Test_Service_Definition_WantedBy_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Config : constant Podmander.Config.Service_Definition :=
        (Name          => Null_Unbounded_String,
         Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others => (Key => Null_Unbounded_String, Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others => (Host => 1, Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others => (Host => Null_Unbounded_String, Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => To_Unbounded_String ("multi-user.target"));
   begin
      Assert (To_String (Config.WantedBy) = "multi-user.target", "WantedBy should be 'multi-user.target'");
   end Test_Service_Definition_WantedBy_Field;

   --  Register all test routines
   overriding
   procedure Register_Tests (T : in out Config_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Service_Definition_Construction'Access, "Constructing a Service_Definition with valid fields");
      Register_Routine (T, Test_Port_Mapping_Construction'Access, "Constructing a Port_Mapping with valid fields");
      Register_Routine (T, Test_Parse_Valid_File'Access, "Parsing a valid TOML file with all fields");
      Register_Routine (T, Test_Parse_Missing_Image'Access, "Parsing a TOML file with missing image field should fail");
      Register_Routine (T, Test_Parse_Nonexistent_File'Access, "Parsing a nonexistent file should fail with error");
      Register_Routine (T, Test_Parse_Invalid_Syntax'Access, "Parsing TOML syntax error should fail");
      Register_Routine (T, Test_Valid_Config_Passes_Validation'Access, "Valid config passes validation");
      Register_Routine (T, Test_Empty_Image_Fails_Validation'Access, "Empty image fails validation");
      Register_Routine
        (T, Test_Port_Out_Of_Range_Fails_Validation'Access, "Port out of range (65536) fails validation");
      Register_Routine (T, Test_Empty_Volume_Path_Fails_Validation'Access, "Empty volume path fails validation");
      Register_Routine
        (T, Test_Parse_Extracts_Service_Name'Access, "Parser extracts service name from [service.<name>] header");
      Register_Routine
        (T, Test_Service_Definition_Name_Field'Access, "Constructing a Service_Definition with Name field");
      Register_Routine
        (T,
         Test_Service_Definition_Description_Field'Access,
         "Constructing a Service_Definition with Description field");
      Register_Routine
        (T, Test_Service_Definition_WantedBy_Field'Access, "Constructing a Service_Definition with WantedBy field");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Config_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Config_Tests;
