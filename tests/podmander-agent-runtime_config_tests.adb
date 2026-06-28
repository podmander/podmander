with Ada.Directories;
with Ada.Characters.Latin_1;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Agent.Runtime_Config;
with Podmander.Logging;

package body Podmander.Agent.Runtime_Config_Tests is

   use Ada.Characters.Latin_1;
   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Logging;

   type Test_Case_Type is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Test_Case_Type) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Agent.Runtime_Config"));
   overriding
   procedure Register_Tests (T : in out Test_Case_Type);

   Tmp     : constant String := "/tmp/podmander-agent-runtime-config-tests";
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

   procedure Assert_Failure
     (Result : Podmander.Agent.Runtime_Config.Load_Result) is
   begin
      Assert (not Result.Success, "expected failure");
      Assert (To_String (Result.Message)'Length > 0, "message required");
   end Assert_Failure;

   procedure Test_Default_Path_Constant
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Actual : constant String :=
        Runtime_String (Podmander.Agent.Runtime_Config.Default_Config_Path);
   begin
      Assert (Actual = "/etc/podmander/agent.toml", "default path constant");
   end Test_Default_Path_Constant;

   procedure Test_Missing_Default_No_Token_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load;
   begin
      Assert_Failure (Result);
   end Test_Missing_Default_No_Token_Fails;

   procedure Test_Missing_Default_With_Token_Succeeds
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load (Token_Override => "tok");
   begin
      Assert (Result.Success, "token override should succeed");
      Assert
        (To_String (Result.Value.Config.Controller_Address)
         = "tcp://localhost:5555",
         "default connect");
      Assert
        (To_String (Result.Value.Config.Agent_Name) = "agent-1",
         "default name");
      Assert
        (Result.Value.Config.Heartbeat_Interval = 30.0, "default interval");
      Assert
        (Result.Value.Log_Level = Podmander.Logging.Info, "default log level");
      Assert
        (To_String (Result.Value.Config.Join_Token) = "tok", "token override");
   end Test_Missing_Default_With_Token_Succeeds;

   procedure Test_Explicit_Missing_File_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load
          (Config_Path          => "/nonexistent/agent.toml",
           Config_Path_Explicit => True);
   begin
      Assert_Failure (Result);
   end Test_Explicit_Missing_File_Fails;

   procedure Test_File_Happy_Path (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load (Config_Path => Fixture);
   begin
      Assert (Result.Success, "file load");
      Assert
        (To_String (Result.Value.Config.Controller_Address)
         = "tcp://file:5555",
         "connect");
      Assert
        (To_String (Result.Value.Config.Join_Token) = "file-token", "token");
      Assert
        (To_String (Result.Value.Config.Agent_Name) = "file-agent", "name");
      Assert (Result.Value.Config.Heartbeat_Interval = 45.0, "interval");
      Assert (Result.Value.Log_Level = Podmander.Logging.Warning, "log level");
   end Test_File_Happy_Path;

   procedure Test_CLI_Overrides_Beat_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load
          (Config_Path        => Fixture,
           Connect_Override   => "tcp://override:5555",
           Token_Override     => "override-token",
           Name_Override      => "override-agent",
           Interval_Override  => "12.5",
           Log_Level_Override => "error");
   begin
      Assert (Result.Success, "overrides");
      Assert
        (To_String (Result.Value.Config.Controller_Address)
         = "tcp://override:5555",
         "connect override");
      Assert
        (To_String (Result.Value.Config.Join_Token) = "override-token",
         "token override");
      Assert
        (To_String (Result.Value.Config.Agent_Name) = "override-agent",
         "name override");
      Assert
        (Result.Value.Config.Heartbeat_Interval = 12.5, "interval override");
      Assert
        (Result.Value.Log_Level = Podmander.Logging.Error, "log override");
   end Test_CLI_Overrides_Beat_File;

   procedure Test_Token_From_File_Succeeds
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load (Config_Path => Fixture);
   begin
      Assert
        (To_String (Result.Value.Config.Join_Token) = "file-token",
         "file token used");
   end Test_Token_From_File_Succeeds;

   procedure Test_Invalid_TOML_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "connect = " & LF);
      declare
         Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert_Failure (Result);
      end;
   end Test_Invalid_TOML_Fails;

   procedure Test_Unreadable_Path_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Tmp & "/unreadable.toml";
   begin
      if Ada.Directories.Exists (Dir) then
         Ada.Directories.Delete_Tree (Dir);
      end if;
      Ada.Directories.Create_Path (Dir);
      declare
         Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path => Dir, Config_Path_Explicit => True);
      begin
         Assert_Failure (Result);
      end;
   end Test_Unreadable_Path_Fails;

   procedure Test_Wrong_Type_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "interval = ""nope""" & LF);
      declare
         Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert_Failure (Result);
      end;
   end Test_Wrong_Type_Fails;

   procedure Test_Unknown_Key_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "bogus = 1" & LF);
      declare
         Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert_Failure (Result);
      end;
   end Test_Unknown_Key_Fails;

   procedure Test_Invalid_Log_Level_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "log_level = ""noisy""" & LF);
      declare
         Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert_Failure (Result);
      end;
   end Test_Invalid_Log_Level_Fails;

   procedure Test_Invalid_Interval_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "interval = ""bad""" & LF);
      declare
         Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert_Failure (Result);
      end;
   end Test_Invalid_Interval_Fails;

   procedure Test_Non_Positive_Interval_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Write_File (Fixture, "interval = 0.0" & LF);
      declare
         Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
           Podmander.Agent.Runtime_Config.Load
             (Config_Path => Fixture, Config_Path_Explicit => True);
      begin
         Assert_Failure (Result);
      end;
   end Test_Non_Positive_Interval_Fails;

   procedure Test_Invalid_Interval_Override_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load
          (Token_Override => "tok", Interval_Override => "bad");
   begin
      Assert_Failure (Result);
   end Test_Invalid_Interval_Override_Fails;

   procedure Test_Non_Positive_Interval_Override_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load
          (Token_Override => "tok", Interval_Override => "0.0");
   begin
      Assert_Failure (Result);
   end Test_Non_Positive_Interval_Override_Fails;

   procedure Test_Missing_Final_Token_Fails
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Result : constant Podmander.Agent.Runtime_Config.Load_Result :=
        Podmander.Agent.Runtime_Config.Load
          (Config_Path => Fixture, Config_Path_Explicit => True);
   begin
      Assert_Failure (Result);
   end Test_Missing_Final_Token_Fails;

   overriding
   procedure Register_Tests (T : in out Test_Case_Type) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Default_Path_Constant'Access, "default path constant");
      Register_Routine
        (T, Test_Missing_Default_No_Token_Fails'Access, "missing token fails");
      Register_Routine
        (T,
         Test_Missing_Default_With_Token_Succeeds'Access,
         "token override succeeds");
      Register_Routine
        (T,
         Test_Explicit_Missing_File_Fails'Access,
         "explicit missing file fails");
      Register_Routine (T, Test_File_Happy_Path'Access, "file happy path");
      Register_Routine
        (T, Test_CLI_Overrides_Beat_File'Access, "cli overrides beat file");
      Register_Routine
        (T, Test_Token_From_File_Succeeds'Access, "token from file succeeds");
      Register_Routine
        (T, Test_Invalid_TOML_Fails'Access, "invalid toml fails");
      Register_Routine
        (T, Test_Unreadable_Path_Fails'Access, "unreadable path fails");
      Register_Routine (T, Test_Wrong_Type_Fails'Access, "wrong type fails");
      Register_Routine (T, Test_Unknown_Key_Fails'Access, "unknown key fails");
      Register_Routine
        (T, Test_Invalid_Log_Level_Fails'Access, "invalid log level fails");
      Register_Routine
        (T, Test_Invalid_Interval_Fails'Access, "invalid interval fails");
      Register_Routine
        (T,
         Test_Non_Positive_Interval_Fails'Access,
         "non-positive interval fails");
      Register_Routine
        (T,
         Test_Invalid_Interval_Override_Fails'Access,
         "invalid interval override fails");
      Register_Routine
        (T,
         Test_Non_Positive_Interval_Override_Fails'Access,
         "non-positive interval override fails");
      Register_Routine
        (T,
         Test_Missing_Final_Token_Fails'Access,
         "missing final token fails");
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
      "connect = ""tcp://file:5555"""
      & LF
      & "token = ""file-token"""
      & LF
      & "name = ""file-agent"""
      & LF
      & "interval = 45.0"
      & LF
      & "log_level = ""warning"""
      & LF);
end Podmander.Agent.Runtime_Config_Tests;
