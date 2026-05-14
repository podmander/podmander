--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Podmander.Config;
with Podmander.Generators.Quadlet;

package body Podmander.Generators.Quadlet_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Config;
   use Podmander.Generators.Quadlet;

   type Quadlet_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name
     (T : Quadlet_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Generators.Quadlet"));

   overriding procedure Register_Tests (T : in out Quadlet_Test);

   --  Test rendering a minimal service with only Image set
   procedure Test_Render_Minimal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
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
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "[Container]") > 0,
              "Output should contain [Container] section");
      Assert (Ada.Strings.Fixed.Index
                (Output, "ContainerImage=nginx:latest") > 0,
              "Output should contain ContainerImage=nginx:latest");
   end Test_Render_Minimal;

   --  Test rendering a service with one environment variable
   procedure Test_Render_Single_Env
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [1 => (Key   => To_Unbounded_String ("FOO"),
                                 Value => To_Unbounded_String ("bar")),
                           others =>
                             (Key   => Null_Unbounded_String,
                              Value => Null_Unbounded_String)],
         Env_Count     => 1,
         Ports         => [others =>
                             (Host      => 1,
                              Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others =>
                             (Host      => Null_Unbounded_String,
                              Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "Environment=FOO=bar") > 0,
              "Output should contain Environment=FOO=bar");
   end Test_Render_Single_Env;

   --  Test rendering a service with two environment variables
   procedure Test_Render_Multiple_Env
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [1 => (Key   => To_Unbounded_String ("FOO"),
                                 Value => To_Unbounded_String ("bar")),
                           2 => (Key   => To_Unbounded_String ("BAZ"),
                                 Value => To_Unbounded_String ("qux")),
                           others =>
                             (Key   => Null_Unbounded_String,
                              Value => Null_Unbounded_String)],
         Env_Count     => 2,
         Ports         => [others =>
                             (Host      => 1,
                              Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others =>
                             (Host      => Null_Unbounded_String,
                              Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "Environment=FOO=bar") > 0,
              "Output should contain Environment=FOO=bar");
      Assert (Ada.Strings.Fixed.Index (Output, "Environment=BAZ=qux") > 0,
              "Output should contain Environment=BAZ=qux");
   end Test_Render_Multiple_Env;

   --  Test rendering a service with one port mapping
   procedure Test_Render_Single_Port
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others =>
                             (Key   => Null_Unbounded_String,
                              Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [1 => (Host      => 8080,
                                 Container => 80),
                           others =>
                             (Host      => 1,
                              Container => 1)],
         Ports_Count   => 1,
         Volumes       => [others =>
                             (Host      => Null_Unbounded_String,
                              Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "PublishPort=8080:80") > 0,
              "Output should contain PublishPort=8080:80");
   end Test_Render_Single_Port;

   --  Test rendering a service with two port mappings
   procedure Test_Render_Multiple_Ports
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others =>
                             (Key   => Null_Unbounded_String,
                              Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [1 => (Host      => 8080,
                                 Container => 80),
                           2 => (Host      => 443,
                                 Container => 443),
                           others =>
                             (Host      => 1,
                              Container => 1)],
         Ports_Count   => 2,
         Volumes       => [others =>
                             (Host      => Null_Unbounded_String,
                              Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "PublishPort=8080:80") > 0,
              "Output should contain PublishPort=8080:80");
      Assert (Ada.Strings.Fixed.Index (Output, "PublishPort=443:443") > 0,
              "Output should contain PublishPort=443:443");
   end Test_Render_Multiple_Ports;

   --  Test rendering a service with one volume mapping
   procedure Test_Render_Single_Volume
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others =>
                             (Key   => Null_Unbounded_String,
                              Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [others =>
                             (Host      => 1,
                              Container => 1)],
         Ports_Count   => 0,
         Volumes       => [1 => (Host      => To_Unbounded_String ("/data"),
                                 Container => To_Unbounded_String ("/data")),
                           others =>
                             (Host      => Null_Unbounded_String,
                              Container => Null_Unbounded_String)],
         Volumes_Count => 1,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "Volume=/data:/data") > 0,
              "Output should contain Volume=/data:/data");
   end Test_Render_Single_Volume;

   --  Test rendering a full container with all field types
   procedure Test_Render_Full_Container
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("myapp:latest"),
         Env           => [1 => (Key   => To_Unbounded_String ("FOO"),
                                 Value => To_Unbounded_String ("bar")),
                           2 => (Key   => To_Unbounded_String ("BAZ"),
                                 Value => To_Unbounded_String ("qux")),
                           others =>
                             (Key   => Null_Unbounded_String,
                              Value => Null_Unbounded_String)],
         Env_Count     => 2,
         Ports         => [1 => (Host      => 8080,
                                 Container => 80),
                           2 => (Host      => 443,
                                 Container => 443),
                           others =>
                             (Host      => 1,
                              Container => 1)],
         Ports_Count   => 2,
         Volumes       => [1 => (Host      => To_Unbounded_String ("/data"),
                                 Container => To_Unbounded_String ("/data")),
                           others =>
                             (Host      => Null_Unbounded_String,
                              Container => Null_Unbounded_String)],
         Volumes_Count => 1,
         Description   => Null_Unbounded_String,
         WantedBy      => Null_Unbounded_String);
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "[Container]") > 0,
              "Output should contain [Container] section");
      Assert (Ada.Strings.Fixed.Index
                (Output, "ContainerImage=myapp:latest") > 0,
              "Output should contain ContainerImage=myapp:latest");
      Assert (Ada.Strings.Fixed.Index (Output, "Environment=FOO=bar") > 0,
              "Output should contain Environment=FOO=bar");
      Assert (Ada.Strings.Fixed.Index (Output, "Environment=BAZ=qux") > 0,
              "Output should contain Environment=BAZ=qux");
      Assert (Ada.Strings.Fixed.Index (Output, "PublishPort=8080:80") > 0,
              "Output should contain PublishPort=8080:80");
      Assert (Ada.Strings.Fixed.Index (Output, "PublishPort=443:443") > 0,
              "Output should contain PublishPort=443:443");
      Assert (Ada.Strings.Fixed.Index (Output, "Volume=/data:/data") > 0,
              "Output should contain Volume=/data:/data");
   end Test_Render_Full_Container;

   --  Register all test routines (Test_Render_Volume_With_Options skipped)
   overriding procedure Register_Tests (T : in out Quadlet_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Render_Minimal'Access,
         "Render minimal service with only Image set");
      Register_Routine
        (T, Test_Render_Single_Env'Access,
         "Render service with one environment variable");
      Register_Routine
        (T, Test_Render_Multiple_Env'Access,
         "Render service with two environment variables");
      Register_Routine
        (T, Test_Render_Single_Port'Access,
         "Render service with one port mapping");
      Register_Routine
        (T, Test_Render_Multiple_Ports'Access,
         "Render service with two port mappings");
      Register_Routine
        (T, Test_Render_Single_Volume'Access,
         "Render service with one volume mapping");
      Register_Routine
        (T, Test_Render_Full_Container'Access,
         "Render full container with all field types");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Quadlet_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Generators.Quadlet_Tests;
