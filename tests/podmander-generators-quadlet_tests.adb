--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
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

   --  Test rendering a service with a Description (should emit [Unit] section)
   procedure Test_Render_Description_Present
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("myapp:latest"),
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
         Description   => To_Unbounded_String ("My web app"),
         WantedBy      => Null_Unbounded_String);
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "[Unit]") > 0,
              "Output should contain [Unit] section");
      Assert (Ada.Strings.Fixed.Index
                (Output, "Description=My web app") > 0,
              "Output should contain Description=My web app");
   end Test_Render_Description_Present;

   --  Test rendering a service with empty Description (no [Unit] section)
   procedure Test_Render_Description_Empty
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("myapp:latest"),
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
      Assert (Ada.Strings.Fixed.Index (Output, "[Unit]") = 0,
              "Output should NOT contain [Unit] section");
   end Test_Render_Description_Empty;

   --  Test rendering a service with explicit WantedBy
   procedure Test_Render_WantedBy_Specified
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("myapp:latest"),
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
         WantedBy      => To_Unbounded_String ("multi-user.target"));
      Output : constant String := Render (Config);
   begin
      Assert (Ada.Strings.Fixed.Index (Output, "[Install]") > 0,
              "Output should contain [Install] section");
      Assert (Ada.Strings.Fixed.Index
                (Output, "WantedBy=multi-user.target") > 0,
              "Output should contain WantedBy=multi-user.target");
   end Test_Render_WantedBy_Specified;

   --  Test rendering a service with default WantedBy
   procedure Test_Render_WantedBy_Default
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("myapp:latest"),
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
      Assert (Ada.Strings.Fixed.Index (Output, "[Install]") > 0,
              "Output should contain [Install] section");
      Assert (Ada.Strings.Fixed.Index
                (Output, "WantedBy=multi-user.target") > 0,
              "Output should contain default WantedBy=multi-user.target");
   end Test_Render_WantedBy_Default;

   --  Test sections appear in correct order: [Unit] < [Container] < [Install]
   procedure Test_Render_Full_Sections
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("myapp:latest"),
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
         Description   => To_Unbounded_String ("My web app"),
         WantedBy      => To_Unbounded_String ("multi-user.target"));
      Output    : constant String := Render (Config);
      Unit_Pos      : constant Natural :=
        Ada.Strings.Fixed.Index (Output, "[Unit]");
      Container_Pos : constant Natural :=
        Ada.Strings.Fixed.Index (Output, "[Container]");
      Install_Pos   : constant Natural :=
        Ada.Strings.Fixed.Index (Output, "[Install]");
   begin
      Assert (Unit_Pos > 0, "Output should contain [Unit] section");
      Assert (Container_Pos > 0,
              "Output should contain [Container] section");
      Assert (Install_Pos > 0,
              "Output should contain [Install] section");
      Assert (Unit_Pos < Container_Pos,
              "[Unit] section should appear before [Container]");
      Assert (Container_Pos < Install_Pos,
              "[Container] section should appear before [Install]");
   end Test_Render_Full_Sections;

   --  Test Write_File creates a .container file on disk
   procedure Test_Write_File_Creates_File
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
      Dir   : constant String := "/tmp/podmander-test-write";
      FName : constant String := "test-svc";
      FPath : constant String := Dir & "/" & FName & ".container";
   begin
      --  Clean up from previous runs
      begin
         Ada.Directories.Delete_Tree (Dir);
      exception
         when others => null;
      end;

      Write_File (Config, Dir, FName);

      Assert (Ada.Directories.Exists (FPath),
              "File " & FPath & " should exist");

      --  Clean up
      Ada.Directories.Delete_Tree (Dir);
   exception
      when others =>
         begin
            Ada.Directories.Delete_Tree (Dir);
         exception
            when others => null;
         end;
         raise;
   end Test_Write_File_Creates_File;

   --  Test Write_File creates the output directory if it does not exist
   procedure Test_Write_File_Creates_Directory
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
      Dir   : constant String := "/tmp/podmander-test-mkdir/sub";
      FName : constant String := "test-svc";
      FPath : constant String := Dir & "/" & FName & ".container";
   begin
      --  Clean up from previous runs
      begin
         Ada.Directories.Delete_Tree (Dir);
      exception
         when others => null;
      end;

      Write_File (Config, Dir, FName);

      Assert (Ada.Directories.Exists (Dir),
              "Directory " & Dir & " should exist");
      Assert (Ada.Directories.Exists (FPath),
              "File " & FPath & " should exist");

      --  Clean up
      Ada.Directories.Delete_Tree (Dir);
   exception
      when others =>
         begin
            Ada.Directories.Delete_Tree (Dir);
         exception
            when others => null;
         end;
         raise;
   end Test_Write_File_Creates_Directory;

   --  Test Write_File content matches Render output
   procedure Test_Write_File_Content_Matches_Render
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
      Dir      : constant String := "/tmp/podmander-test-content";
      FName    : constant String := "test-svc";
      FPath    : constant String := Dir & "/" & FName & ".container";
      Expected : constant String := Render (Config);
      File     : Ada.Text_IO.File_Type;
      Line     : String (1 .. 1000);
      Last     : Natural;
      Actual   : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      --  Clean up from previous runs
      begin
         Ada.Directories.Delete_Tree (Dir);
      exception
         when others => null;
      end;

      Write_File (Config, Dir, FName);

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, FPath);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         Ada.Strings.Unbounded.Append (Actual, Line (1 .. Last));
         Ada.Strings.Unbounded.Append (Actual, ASCII.LF);
      end loop;
      Ada.Text_IO.Close (File);

      Assert (Ada.Strings.Unbounded.To_String (Actual) = Expected,
              "File content should match Render output");

      --  Clean up
      Ada.Directories.Delete_Tree (Dir);
   exception
      when others =>
         begin
            Ada.Directories.Delete_Tree (Dir);
         exception
            when others => null;
         end;
         raise;
   end Test_Write_File_Content_Matches_Render;

   ---------------
   --  Read_File  --
   ---------------

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Strings.Unbounded.Append
           (Content, Ada.Text_IO.Get_Line (File));
         if not Ada.Text_IO.End_Of_File (File) then
            Ada.Strings.Unbounded.Append (Content, ASCII.LF);
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Read_File;

   --  Fixture comparison minimal.container: Image only, no Description
   procedure Test_Golden_Minimal
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
      Golden : constant String :=
        Read_File ("tests/fixtures/quadlet/minimal.container") & ASCII.LF;
      Output : constant String := Render (Config);
   begin
      Assert (Output = Golden,
              "Render output for minimal config should match fixture file");
   end Test_Golden_Minimal;

   --  Fixture comparison full.container: Description, Image, 2 env, 2 ports, 1 volume
   procedure Test_Golden_Full
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
         Ports         => [1 => (Host      => 80,
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
         Description   => To_Unbounded_String ("My web app"),
         WantedBy      => To_Unbounded_String ("multi-user.target"));
      Golden : constant String :=
        Read_File ("tests/fixtures/quadlet/full.container") & ASCII.LF;
      Output : constant String := Render (Config);
   begin
      Assert (Output = Golden,
              "Render output for full config should match fixture file");
   end Test_Golden_Full;

   --  Fixture comparison multi-env.container: 3 environment variables
   procedure Test_Golden_Multi_Env
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("app:latest"),
         Env           => [1 => (Key   => To_Unbounded_String ("FOO"),
                                 Value => To_Unbounded_String ("bar")),
                           2 => (Key   => To_Unbounded_String ("BAZ"),
                                 Value => To_Unbounded_String ("qux")),
                           3 => (Key   => To_Unbounded_String ("APP_ENV"),
                                 Value => To_Unbounded_String ("production")),
                           others =>
                             (Key   => Null_Unbounded_String,
                              Value => Null_Unbounded_String)],
         Env_Count     => 3,
         Ports         => [others =>
                             (Host      => 1,
                              Container => 1)],
         Ports_Count   => 0,
         Volumes       => [others =>
                             (Host      => Null_Unbounded_String,
                              Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => To_Unbounded_String ("Env test"),
         WantedBy      => Null_Unbounded_String);
      Golden : constant String :=
        Read_File ("tests/fixtures/quadlet/multi-env.container") & ASCII.LF;
      Output : constant String := Render (Config);
   begin
      Assert (Output = Golden,
              "Render output for multi-env config should match fixture file");
   end Test_Golden_Multi_Env;

   --  Fixture comparison multi-port.container: 3 port mappings
   procedure Test_Golden_Multi_Port
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Config : constant Service_Definition :=
        (Image         => To_Unbounded_String ("nginx:latest"),
         Env           => [others =>
                             (Key   => Null_Unbounded_String,
                              Value => Null_Unbounded_String)],
         Env_Count     => 0,
         Ports         => [1 => (Host      => 80,
                                 Container => 8080),
                           2 => (Host      => 443,
                                 Container => 8443),
                           3 => (Host      => 53,
                                 Container => 53),
                           others =>
                             (Host      => 1,
                              Container => 1)],
         Ports_Count   => 3,
         Volumes       => [others =>
                             (Host      => Null_Unbounded_String,
                              Container => Null_Unbounded_String)],
         Volumes_Count => 0,
         Description   => To_Unbounded_String ("Port test"),
         WantedBy      => Null_Unbounded_String);
      Golden : constant String :=
        Read_File ("tests/fixtures/quadlet/multi-port.container") & ASCII.LF;
      Output : constant String := Render (Config);
   begin
      Assert (Output = Golden,
              "Render output for multi-port config should match fixture file");
   end Test_Golden_Multi_Port;

   --  Register all test routines
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
      Register_Routine
        (T, Test_Render_Description_Present'Access,
         "Render service with Description present");
      Register_Routine
        (T, Test_Render_Description_Empty'Access,
         "Render service with empty Description");
      Register_Routine
        (T, Test_Render_WantedBy_Specified'Access,
         "Render service with explicit WantedBy");
      Register_Routine
        (T, Test_Render_WantedBy_Default'Access,
         "Render service with default WantedBy");
      Register_Routine
        (T, Test_Render_Full_Sections'Access,
         "Render service with all sections in correct order");
      Register_Routine
        (T, Test_Write_File_Creates_File'Access,
         "Write_File creates a .container file on disk");
      Register_Routine
        (T, Test_Write_File_Creates_Directory'Access,
         "Write_File creates output directory if it does not exist");
      Register_Routine
         (T, Test_Write_File_Content_Matches_Render'Access,
          "Write_File content matches Render output");
      Register_Routine
         (T, Test_Golden_Minimal'Access,
          "Golden minimal: Image only, no Description");
      Register_Routine
         (T, Test_Golden_Full'Access,
          "Golden full: Description, Image, 2 env, 2 ports, 1 volume");
      Register_Routine
         (T, Test_Golden_Multi_Env'Access,
          "Golden multi-env: 3 environment variables");
      Register_Routine
         (T, Test_Golden_Multi_Port'Access,
          "Golden multi-port: 3 port mappings");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Quadlet_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Generators.Quadlet_Tests;
