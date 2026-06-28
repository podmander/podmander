--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;

with TOML;
with TOML.File_IO;

package body Podmander.Agent.Runtime_Config is

   use type TOML.Float_Kind;

   function To_Log_Level (Value : String) return Podmander.Logging.Log_Level is
   begin
      if Value = "debug" then
         return Podmander.Logging.Debug;
      elsif Value = "info" then
         return Podmander.Logging.Info;
      elsif Value = "warning" then
         return Podmander.Logging.Warning;
      elsif Value = "error" then
         return Podmander.Logging.Error;
      elsif Value = "critical" then
         return Podmander.Logging.Critical;
      end if;

      raise Constraint_Error;
   end To_Log_Level;

   function Path_Exists (Path : String) return Boolean
   is (Ada.Directories.Exists (Path));

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

   function Load
     (Config_Path          : String := Default_Config_Path;
      Config_Path_Explicit : Boolean := False;
      Connect_Override     : String := "";
      Token_Override       : String := "";
      Name_Override        : String := "";
      Interval_Override    : String := "";
      Log_Level_Override   : String := "") return Load_Result
   is
      Config : Podmander.Agent.Agent_Config :=
        (Controller_Address   => To_Unbounded_String ("tcp://localhost:5555"),
         Agent_Name           => To_Unbounded_String ("agent-1"),
         Join_Token           => Null_Unbounded_String,
         Heartbeat_Interval   => 30.0,
         Registration_Timeout => 5.0,
         Max_Backoff          => 60.0);
      Level  : Podmander.Logging.Log_Level := Podmander.Logging.Info;
   begin
      if Config_Path /= "" and then Path_Exists (Config_Path) then
         declare
            Result : TOML.Read_Result;
         begin
            case Ada.Directories.Kind (Config_Path) is
               when Ada.Directories.Ordinary_File =>
                  null;

               when others                        =>
                  return
                    (Success => False,
                     Message =>
                       To_Unbounded_String
                         ("unable to load config file: " & Config_Path));
            end case;

            begin
               Result := TOML.File_IO.Load_File (Config_Path);
            exception
               when others =>
                  return
                    (Success => False,
                     Message =>
                       To_Unbounded_String
                         ("unable to load config file: " & Config_Path));
            end;

            if not Result.Success then
               return
                 (Success => False,
                  Message => To_Unbounded_String (TOML.Format_Error (Result)));
            else
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
                        Config.Heartbeat_Interval :=
                          Read_Interval (Table_Entry.Value);
                        if Config.Heartbeat_Interval <= 0.0 then
                           return
                             (Success => False,
                              Message =>
                                To_Unbounded_String ("invalid interval"));
                        end if;
                     elsif Key = "log_level" then
                        Level := To_Log_Level (Table_Entry.Value.As_String);
                     else
                        return
                          (Success => False,
                           Message =>
                             To_Unbounded_String ("unknown key: " & Key));
                     end if;
                  exception
                     when Constraint_Error | Program_Error =>
                        return
                          (Success => False,
                           Message =>
                             To_Unbounded_String
                               ("invalid value for key: " & Key));
                  end;
               end loop;
            end if;
         end;
      elsif Config_Path_Explicit then
         return
           (Success => False,
            Message =>
              To_Unbounded_String ("config file not found: " & Config_Path));
      end if;

      if Connect_Override /= "" then
         Config.Controller_Address := To_Unbounded_String (Connect_Override);
      end if;

      if Token_Override /= "" then
         Config.Join_Token := To_Unbounded_String (Token_Override);
      end if;

      if Name_Override /= "" then
         Config.Agent_Name := To_Unbounded_String (Name_Override);
      end if;

      if Interval_Override /= "" then
         begin
            Config.Heartbeat_Interval := Duration'Value (Interval_Override);
            if Config.Heartbeat_Interval <= 0.0 then
               return
                 (Success => False,
                  Message => To_Unbounded_String ("invalid interval"));
            end if;
         exception
            when others =>
               return
                 (Success => False,
                  Message => To_Unbounded_String ("invalid interval"));
         end;
      end if;

      if Log_Level_Override /= "" then
         begin
            Level := To_Log_Level (Log_Level_Override);
         exception
            when others =>
               return
                 (Success => False,
                  Message => To_Unbounded_String ("invalid log level"));
         end;
      end if;

      if Config.Join_Token = Null_Unbounded_String then
         return
           (Success => False,
            Message => To_Unbounded_String ("token is required"));
      end if;

      return
        (Success => True, Value => (Config => Config, Log_Level => Level));
   end Load;

end Podmander.Agent.Runtime_Config;
