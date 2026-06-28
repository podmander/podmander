--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;

with Podmander.Runtime_Config_Helpers;
with TOML;
with TOML.File_IO;

package body Podmander.Agent.Runtime_Config is

   use type TOML.Float_Kind;

   function Failure (Message : String) return Load_Result
   is (Success => False, Message => To_Unbounded_String (Message));

   function Success_Result
     (Config : Podmander.Agent.Agent_Config;
      Level  : Podmander.Logging.Log_Level) return Load_Result
   is (Success => True, Value => (Config => Config, Log_Level => Level));

   function Default_Config return Podmander.Agent.Agent_Config
   is (Controller_Address   => To_Unbounded_String ("tcp://localhost:5555"),
       Agent_Name           => To_Unbounded_String ("agent-1"),
       Join_Token           => Null_Unbounded_String,
       Heartbeat_Interval   => 30.0,
       Registration_Timeout => 5.0,
       Max_Backoff          => 60.0);

   function Read_Interval (Value : TOML.TOML_Value) return Duration is
   begin
      case Value.Kind is
         when TOML.TOML_Float   =>
            declare
               Float_Value : constant TOML.Any_Float := Value.As_Float;
            begin
               if Float_Value.Kind /= TOML.Regular then
                  raise Constraint_Error;
               end if;

               return Duration (Float_Value.Value);
            end;

         when TOML.TOML_Integer =>
            return Duration (Value.As_Integer);

         when others            =>
            raise Constraint_Error;
      end case;
   end Read_Interval;

   function Apply_Config_File
     (Config_Path : String;
      Config      : in out Podmander.Agent.Agent_Config;
      Level       : in out Podmander.Logging.Log_Level) return Load_Result
   is
      Result : TOML.Read_Result;
   begin
      case Ada.Directories.Kind (Config_Path) is
         when Ada.Directories.Ordinary_File =>
            null;

         when others                        =>
            return Failure ("unable to load config file: " & Config_Path);
      end case;

      begin
         Result := TOML.File_IO.Load_File (Config_Path);
      exception
         when others =>
            return Failure ("unable to load config file: " & Config_Path);
      end;

      if not Result.Success then
         return Failure (TOML.Format_Error (Result));
      end if;

      for Table_Entry of Result.Value.Iterate_On_Table loop
         declare
            Key : constant String := To_String (Table_Entry.Key);
         begin
            if Key = "connect" then
               Config.Controller_Address :=
                 To_Unbounded_String (Table_Entry.Value.As_String);
            elsif Key = "token" then
               Config.Join_Token :=
                 To_Unbounded_String (Table_Entry.Value.As_String);
            elsif Key = "name" then
               Config.Agent_Name :=
                 To_Unbounded_String (Table_Entry.Value.As_String);
            elsif Key = "interval" then
               Config.Heartbeat_Interval := Read_Interval (Table_Entry.Value);
               if Config.Heartbeat_Interval <= 0.0 then
                  return Failure ("invalid interval");
               end if;
            elsif Key = "log_level" then
               Level :=
                 Podmander.Runtime_Config_Helpers.To_Log_Level
                   (Table_Entry.Value.As_String);
            else
               return Failure ("unknown key: " & Key);
            end if;
         exception
            when others =>
               return Failure ("invalid value for key: " & Key);
         end;
      end loop;

      return Success_Result (Config, Level);
   exception
      when others =>
         return Failure ("unable to load config file: " & Config_Path);
   end Apply_Config_File;

   function Apply_Overrides
     (Overrides : Config_Overrides;
      Config    : in out Podmander.Agent.Agent_Config;
      Level     : in out Podmander.Logging.Log_Level) return Load_Result is
   begin
      if Overrides.Connect /= Null_Unbounded_String then
         Config.Controller_Address := Overrides.Connect;
      end if;
      if Overrides.Token /= Null_Unbounded_String then
         Config.Join_Token := Overrides.Token;
      end if;
      if Overrides.Name /= Null_Unbounded_String then
         Config.Agent_Name := Overrides.Name;
      end if;
      if Overrides.Interval /= Null_Unbounded_String then
         begin
            Config.Heartbeat_Interval :=
              Duration'Value (To_String (Overrides.Interval));
            if Config.Heartbeat_Interval <= 0.0 then
               return Failure ("invalid interval");
            end if;
         exception
            when others =>
               return Failure ("invalid interval");
         end;
      end if;
      if Overrides.Log_Level /= Null_Unbounded_String then
         begin
            Level :=
              Podmander.Runtime_Config_Helpers.To_Log_Level
                (To_String (Overrides.Log_Level));
         exception
            when others =>
               return Failure ("invalid log level");
         end;
      end if;

      return Success_Result (Config, Level);
   end Apply_Overrides;

   function Load
     (Config_Path          : String := Default_Config_Path;
      Config_Path_Explicit : Boolean := False;
      Overrides            : Config_Overrides := Default_Overrides)
      return Load_Result
   is
      Config : Podmander.Agent.Agent_Config := Default_Config;
      Level  : Podmander.Logging.Log_Level := Podmander.Logging.Info;
   begin
      if Config_Path /= "" and then Ada.Directories.Exists (Config_Path) then
         declare
            Result : constant Load_Result :=
              Apply_Config_File (Config_Path, Config, Level);
         begin
            if not Result.Success then
               return Result;
            end if;
         end;
      elsif Config_Path_Explicit then
         return Failure ("config file not found: " & Config_Path);
      end if;

      declare
         Result : constant Load_Result :=
           Apply_Overrides (Overrides, Config, Level);
      begin
         if not Result.Success then
            return Result;
         end if;
      end;

      if Config.Join_Token = Null_Unbounded_String then
         return Failure ("token is required");
      end if;

      return Success_Result (Config, Level);
   end Load;

end Podmander.Agent.Runtime_Config;
