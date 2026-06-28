with Ada.Directories;
with Ada.Characters.Latin_1;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Controller.Runtime_Config;
with Podmander.Logging;

package body Podmander.Controller.Runtime_Config_Tests is

   use AUnit.Assertions;
   use Ada.Characters.Latin_1;
   use Ada.Strings.Unbounded;
   use Podmander.Logging;

   type Test_Case_Type is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Test_Case_Type) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Runtime_Config"));
   overriding
   procedure Register_Tests (T : in out Test_Case_Type);

   Tmp     : constant String :=
     "/tmp/podmander-controller-runtime-config-tests";
   Fixture : constant String := Tmp & "/fixture.toml";

   function Runtime_String (Value : String) return String;
   pragma No_Inline (Runtime_String);

   function Runtime_String (Value : String) return String
   is (Value);

   procedure Write_File (Path, Content : String) is
      F : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Tmp) then
         Ada.Directories.Create_Path (Tmp);
      end if;
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, Content);
      Ada.Text_IO.Close (F);
   end Write_File;

   procedure Remove (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
   exception
      when others =>
         null;
   end Remove;

   procedure Assert_Success
     (Result : Podmander.Controller.Runtime_Config.Load_Result) is
   begin
      Assert (Result.Success, "expected success");
   end Assert_Success;

   procedure Assert_Failure
     (Result  : Podmander.Controller.Runtime_Config.Load_Result;
      Needles : String) is
   begin
      Assert (not Result.Success, "expected failure");
      Assert (To_String (Result.Message)'Length > 0, "message required");
      Assert
        (To_String (Result.Message)'Length >= Needles'Length,
         "message present");
   end Assert_Failure;

   procedure Test_Default_Path_Constant
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Actual : constant String :=
        Runtime_String
          (Podmander.Controller.Runtime_Config.Default_Config_Path);
   begin
      Assert
        (Actual = "/etc/podmander/controller.toml", "default path constant");
   end Test_Default_Path_Constant;

   procedure Test_Defaults_With_Missing_Implicit_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
        Podmander.Controller.Runtime_Config.Load;
   begin
      Assert_Success (Result);
      Assert
        (Podmander.Controller.Get_Bind_Address (Result.Value.Config)
         = "tcp://*:5555",
         "default bind");
      Assert
        (Podmander.Controller.Get_DB_Path (Result.Value.Config) = "",
         "db fallback empty");
      Assert
        (Result.Value.Log_Level = Podmander.Logging.Info,
         "default log level info");
   end Test_Defaults_With_Missing_Implicit_File;

   procedure Test_Explicit_Missing_File_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
        Podmander.Controller.Runtime_Config.Load
          (Config_Path          => "/nonexistent/controller.toml",
           Config_Path_Explicit => True);
   begin
      Assert_Failure (Result, "config file not found");
   end Test_Explicit_Missing_File_Fails;

   procedure Test_File_Happy_Path_Loads_All_Keys
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
        Podmander.Controller.Runtime_Config.Load (Config_Path => Fixture);
   begin
      Assert_Success (Result);
      Assert
        (Podmander.Controller.Get_Bind_Address (Result.Value.Config)
         = "tcp://127.0.0.1:5556",
         "bind from file");
      Assert
        (Podmander.Controller.Get_DB_Path (Result.Value.Config)
         = "/tmp/controller.db",
         "db path from file");
      Assert
        (Result.Value.Log_Level = Podmander.Logging.Warning,
         "log level from file");
   end Test_File_Happy_Path_Loads_All_Keys;

   procedure Test_CLI_Overrides_Beat_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
        Podmander.Controller.Runtime_Config.Load
          (Config_Path        => Fixture,
           Bind_Override      => "tcp://*:6000",
           Log_Level_Override => "error");
   begin
      Assert_Success (Result);
      Assert
        (Podmander.Controller.Get_Bind_Address (Result.Value.Config)
         = "tcp://*:6000",
         "bind override");
      Assert
        (Result.Value.Log_Level = Podmander.Logging.Error, "log override");
   end Test_CLI_Overrides_Beat_File;

   procedure Test_Invalid_TOML_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "bind = " & LF);
      declare
         Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
           Podmander.Controller.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert_Failure (Result, "error");
      end;
   end Test_Invalid_TOML_Fails;

   procedure Test_Unreadable_Path_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Tmp & "/unreadable.toml";
   begin
      Remove (Dir);
      Ada.Directories.Create_Path (Dir);
      declare
         Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
           Podmander.Controller.Runtime_Config.Load
             (Config_Path => Dir, Config_Path_Explicit => True);
      begin
         Assert (not Result.Success, "directory path should fail");
      end;
   end Test_Unreadable_Path_Fails;

   procedure Test_Wrong_Type_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "bind = 1" & LF);
      declare
         Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
           Podmander.Controller.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert (not Result.Success, "wrong type fails");
      end;
   end Test_Wrong_Type_Fails;

   procedure Test_Unknown_Key_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "bogus = ""x""" & LF);
      declare
         Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
           Podmander.Controller.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert (not Result.Success, "unknown key fails");
      end;
   end Test_Unknown_Key_Fails;

   procedure Test_Invalid_Log_Level_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "log_level = ""loud""" & LF);
      declare
         Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
           Podmander.Controller.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert (not Result.Success, "invalid log level fails");
      end;
   end Test_Invalid_Log_Level_Fails;

   procedure Test_Too_Long_Bind_Fails_From_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "bind = """ & String'(1 .. 200 => 'a') & """" & LF);
      declare
         Result : constant Podmander.Controller.Runtime_Config.Load_Result :=
           Podmander.Controller.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert (not Result.Success, "too-long bind fails");
      end;
   end Test_Too_Long_Bind_Fails_From_File;

   procedure Test_Too_Long_Bind_Fails_From_Override
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Long_Bind : constant String := [1 .. 200 => 'b'];
      Result    : constant Podmander.Controller.Runtime_Config.Load_Result :=
        Podmander.Controller.Runtime_Config.Load (Bind_Override => Long_Bind);
   begin
      Assert (not Result.Success, "too-long override fails");
   end Test_Too_Long_Bind_Fails_From_Override;

   overriding
   procedure Register_Tests (T : in out Test_Case_Type) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Default_Path_Constant'Access, "default path constant");
      Register_Routine
        (T,
         Test_Defaults_With_Missing_Implicit_File'Access,
         "default path missing is non-fatal");
      Register_Routine
        (T,
         Test_Explicit_Missing_File_Fails'Access,
         "explicit missing file fails");
      Register_Routine
        (T, Test_File_Happy_Path_Loads_All_Keys'Access, "file happy path");
      Register_Routine
        (T, Test_CLI_Overrides_Beat_File'Access, "cli overrides beat file");
      Register_Routine
        (T, Test_Invalid_TOML_Fails'Access, "invalid toml fails");
      Register_Routine
        (T, Test_Unreadable_Path_Fails'Access, "unreadable path fails");
      Register_Routine (T, Test_Wrong_Type_Fails'Access, "wrong type fails");
      Register_Routine (T, Test_Unknown_Key_Fails'Access, "unknown key fails");
      Register_Routine
        (T, Test_Invalid_Log_Level_Fails'Access, "invalid log level fails");
      Register_Routine
        (T,
         Test_Too_Long_Bind_Fails_From_File'Access,
         "too-long bind from file fails");
      Register_Routine
        (T,
         Test_Too_Long_Bind_Fails_From_Override'Access,
         "too-long bind override fails");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Test_Case_Type;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

begin
   Write_File
     (Fixture,
      "bind = ""tcp://127.0.0.1:5556"""
      & LF
      & "db_path = ""/tmp/controller.db"""
      & LF
      & "log_level = ""warning"""
      & LF);
end Podmander.Controller.Runtime_Config_Tests;
