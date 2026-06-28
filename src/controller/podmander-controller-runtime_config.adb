--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;

with TOML;
with TOML.File_IO;

package body Podmander.Controller.Runtime_Config is

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

   function Invalid_Bind return Unbounded_String
   is (To_Unbounded_String ("invalid bind address"));

   function Path_Exists (Path : String) return Boolean
   is (Ada.Directories.Exists (Path));

   function Load
     (Config_Path          : String := Default_Config_Path;
      Config_Path_Explicit : Boolean := False;
      Bind_Override        : String := "";
      Log_Level_Override   : String := "") return Load_Result
   is
      Config : Podmander.Controller.Controller_Config;
      Level  : Podmander.Logging.Log_Level := Podmander.Logging.Info;
   begin
      Podmander.Controller.Set_Bind_Address (Config, "tcp://*:5555");
      Podmander.Controller.Set_DB_Path (Config, "");

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
            end if;

            for Table_Entry of Result.Value.Iterate_On_Table loop
               declare
                  Key : constant String := To_String (Table_Entry.Key);
               begin
                  if Key = "bind" then
                     begin
                        Podmander.Controller.Set_Bind_Address
                          (Config, Table_Entry.Value.As_String);
                     exception
                        when Constraint_Error | Program_Error =>
                           return (Success => False, Message => Invalid_Bind);
                     end;
                  elsif Key = "db_path" then
                     Podmander.Controller.Set_DB_Path
                       (Config, Table_Entry.Value.As_String);
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
         exception
            when others =>
               return
                 (Success => False,
                  Message =>
                    To_Unbounded_String
                      ("unable to load config file: " & Config_Path));
         end;
      elsif Config_Path_Explicit then
         return
           (Success => False,
            Message =>
              To_Unbounded_String ("config file not found: " & Config_Path));
      end if;

      if Bind_Override /= "" then
         begin
            Podmander.Controller.Set_Bind_Address (Config, Bind_Override);
         exception
            when Constraint_Error | Program_Error =>
               return (Success => False, Message => Invalid_Bind);
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

      return
        (Success => True, Value => (Config => Config, Log_Level => Level));
   end Load;

end Podmander.Controller.Runtime_Config;
