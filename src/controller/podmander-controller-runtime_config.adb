--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;

with Podmander.Runtime_Config_Helpers;
with TOML;
with TOML.File_IO;

package body Podmander.Controller.Runtime_Config is

   function Failure (Message : String) return Load_Result
   is (Success => False, Message => To_Unbounded_String (Message));

   function Success_Result
     (Config : Podmander.Controller.Controller_Config;
      Level  : Podmander.Logging.Log_Level) return Load_Result
   is (Success => True, Value => (Config => Config, Log_Level => Level));

   function Invalid_Bind return Unbounded_String
   is (To_Unbounded_String ("invalid bind address"));

   function Default_Config return Podmander.Controller.Controller_Config is
      Config : Podmander.Controller.Controller_Config;
   begin
      Podmander.Controller.Set_Bind_Address (Config, "tcp://*:5555");
      Podmander.Controller.Set_DB_Path (Config, "");
      return Config;
   end Default_Config;

   function Apply_Config_File
     (Config_Path : String;
      Config      : in out Podmander.Controller.Controller_Config;
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
            if Key = "bind" then
               begin
                  Podmander.Controller.Set_Bind_Address
                    (Config, Table_Entry.Value.As_String);
               exception
                  when others =>
                     return (Success => False, Message => Invalid_Bind);
               end;
            elsif Key = "db_path" then
               Podmander.Controller.Set_DB_Path
                 (Config, Table_Entry.Value.As_String);
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
      Config    : in out Podmander.Controller.Controller_Config;
      Level     : in out Podmander.Logging.Log_Level) return Load_Result is
   begin
      if Overrides.Bind /= Null_Unbounded_String then
         begin
            Podmander.Controller.Set_Bind_Address
              (Config, To_String (Overrides.Bind));
         exception
            when Constraint_Error | Program_Error =>
               return (Success => False, Message => Invalid_Bind);
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
      Config : Podmander.Controller.Controller_Config := Default_Config;
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

      return Success_Result (Config, Level);
   end Load;

end Podmander.Controller.Runtime_Config;
