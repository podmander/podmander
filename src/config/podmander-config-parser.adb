--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Exceptions;
with Ada.Strings.Fixed;

with TOML.File_IO;

package body Podmander.Config.Parser is

   use Ada.Strings.Fixed;
   use TOML;

   -----------
   -- Parse --
   -----------

   function Parse (Path : String) return Parse_Result is
      Load_Result : constant TOML.Read_Result := TOML.File_IO.Load_File (Path);
   begin
      if not Load_Result.Success then
         declare
            Error_Msg : constant String := TOML.Format_Error (Load_Result);
         begin
            return (Success => False, Message => To_Unbounded_String (Error_Msg));
         end;
      end if;

      declare
         Root : constant TOML_Value := Load_Result.Value;
      begin
         -- Check for service table
         if not Root.Has ("service") then
            return (Success => False, Message => To_Unbounded_String ("No [service] section found in config"));
         end if;

         declare
            Service_Table : constant TOML_Value := Root.Get ("service");
            Entries       : constant TOML.Table_Entry_Array := Service_Table.Iterate_On_Table;
         begin
            if Entries'Length = 0 then
               return (Success => False, Message => To_Unbounded_String ("No service definitions found"));
            end if;

            -- Use the first service entry
            declare
               Service_Name  : constant String := To_String (Entries (Entries'First).Key);
               Service_Value : constant TOML_Value := Entries (Entries'First).Value;
               Config        : Service_Definition;
            begin
               -- Service name from [service.<name>] section header
               Config.Name := To_Unbounded_String (Service_Name);

               -- Required field: image
               if not Service_Value.Has ("image") then
                  return
                    (Success => False,
                     Message => To_Unbounded_String ("Missing required field 'image' in" & " service definition"));
               end if;

               Config.Image := To_Unbounded_String (Service_Value.Get ("image").As_String);

               -- Parse env table (optional)
               if Service_Value.Has ("env") then
                  declare
                     Env_Table   : constant TOML_Value := Service_Value.Get ("env");
                     Env_Entries : constant TOML.Table_Entry_Array := Env_Table.Iterate_On_Table;
                  begin
                     for Env_Item of Env_Entries loop
                        if Config.Env_Count < MAX_ENV_ENTRIES then
                           Config.Env (Config.Env_Count + 1) :=
                             (Key => Env_Item.Key, Value => To_Unbounded_String (Env_Item.Value.As_String));
                           Config.Env_Count := Config.Env_Count + 1;
                        end if;
                     end loop;
                  end;
               end if;

               -- Parse ports array (optional)
               if Service_Value.Has ("ports") then
                  declare
                     Ports_Array : constant TOML_Value := Service_Value.Get ("ports");
                  begin
                     for I in 1 .. Ports_Array.Length loop
                        declare
                           Port_Str  : constant String := Ports_Array.Item (I).As_String;
                           Colon_Pos : constant Natural := Index (Port_Str, ":");
                        begin
                           if Colon_Pos > 0 and then Config.Ports_Count < MAX_PORTS_ENTRIES then
                              Config.Ports (Config.Ports_Count + 1) :=
                                (Host      => Positive'Value (Port_Str (Port_Str'First .. Colon_Pos - 1)),
                                 Container => Positive'Value (Port_Str (Colon_Pos + 1 .. Port_Str'Last)));
                              Config.Ports_Count := Config.Ports_Count + 1;
                           end if;
                        end;
                     end loop;
                  end;
               end if;

               -- Parse volumes array (optional)
               if Service_Value.Has ("volumes") then
                  declare
                     Volumes_Array : constant TOML_Value := Service_Value.Get ("volumes");
                  begin
                     for I in 1 .. Volumes_Array.Length loop
                        declare
                           Vol_Str   : constant String := Volumes_Array.Item (I).As_String;
                           Colon_Pos : constant Natural := Index (Vol_Str, ":");
                        begin
                           if Colon_Pos > 0 and then Config.Volumes_Count < MAX_VOLUMES_ENTRIES then
                              Config.Volumes (Config.Volumes_Count + 1) :=
                                (Host      => To_Unbounded_String (Vol_Str (Vol_Str'First .. Colon_Pos - 1)),
                                 Container => To_Unbounded_String (Vol_Str (Colon_Pos + 1 .. Vol_Str'Last)));
                              Config.Volumes_Count := Config.Volumes_Count + 1;
                           end if;
                        end;
                     end loop;
                  end;
               end if;

               -- Validate before returning
               return Validate (Config);
            end;
         end;
      end;
   exception
      when E : others =>
         return
           (Success => False, Message => To_Unbounded_String ("Parse error: " & Ada.Exceptions.Exception_Message (E)));
   end Parse;

   --------------
   -- Validate --
   --------------

   function Validate (Config : Service_Definition) return Parse_Result is
   begin
      -- Image must not be empty
      if Config.Image = Null_Unbounded_String then
         return (Success => False, Message => To_Unbounded_String ("Image must not be empty"));
      end if;

      -- Port host/container must be in valid range
      for I in 1 .. Config.Ports_Count loop
         if Config.Ports (I).Host not in MIN_PORT .. MAX_PORT then
            return
              (Success => False,
               Message =>
                 To_Unbounded_String
                   ("Port host out of range (1-65535): " & Trim (Config.Ports (I).Host'Image, Ada.Strings.Both)));
         end if;
         if Config.Ports (I).Container not in MIN_PORT .. MAX_PORT then
            return
              (Success => False,
               Message =>
                 To_Unbounded_String
                   ("Port container out of range (1-65535): "
                    & Trim (Config.Ports (I).Container'Image, Ada.Strings.Both)));
         end if;
      end loop;

      -- Volume host/container paths must not be empty
      for I in 1 .. Config.Volumes_Count loop
         if Config.Volumes (I).Host = Null_Unbounded_String then
            return (Success => False, Message => To_Unbounded_String ("Volume host path must not be empty"));
         end if;
         if Config.Volumes (I).Container = Null_Unbounded_String then
            return (Success => False, Message => To_Unbounded_String ("Volume container path must not be empty"));
         end if;
      end loop;

      return (Success => True, Config => Config);
   end Validate;

end Podmander.Config.Parser;
