--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Fixed;

with TOML.File_IO;

package body Podmander.Config.Parser is

   use Ada.Strings.Fixed;
   use TOML;

   -------------------------------------------------
   -- Extract_Service_Config (shared by both paths)
   -------------------------------------------------

   function Extract_Service_Config (Root : TOML_Value) return Parse_Result is
      function Failure (Message : String) return Parse_Result
      is (Success => False, Message => To_Unbounded_String (Message));

      function Invalid_Port_Number (Value : String) return Parse_Result is
      begin
         return Failure ("Invalid port number '" & Value & "'");
      end Invalid_Port_Number;

      function Add_Port
        (Config : in out Service_Definition; Port_Str : String)
         return Parse_Result
      is
         Colon_Pos : constant Natural := Index (Port_Str, ":");
      begin
         if Colon_Pos = 0 then
            return
              Failure
                ("Invalid port format '"
                 & Port_Str
                 & "': expected HOST:CONTAINER");
         end if;

         if Config.Ports_Count >= MAX_PORTS_ENTRIES then
            return
              Failure
                ("Too many ports entries (maximum "
                 & Trim (Natural'Image (MAX_PORTS_ENTRIES), Ada.Strings.Both)
                 & ")");
         end if;

         declare
            Host_Text      : constant String :=
              Port_Str (Port_Str'First .. Colon_Pos - 1);
            Container_Text : constant String :=
              Port_Str (Colon_Pos + 1 .. Port_Str'Last);
            Host_Port      : Port_Number := Port_Number'First;
            Container_Port : Port_Number := Port_Number'First;
         begin
            begin
               Host_Port := Port_Number'Value (Host_Text);
            exception
               when Constraint_Error =>
                  return Invalid_Port_Number (Host_Text);
            end;

            begin
               Container_Port := Port_Number'Value (Container_Text);
            exception
               when Constraint_Error =>
                  return Invalid_Port_Number (Container_Text);
            end;

            Config.Ports (Config.Ports_Count + 1) :=
              (Host => Host_Port, Container => Container_Port);
            Config.Ports_Count := Config.Ports_Count + 1;
            return (Success => True, Config => Config);
         end;
      end Add_Port;

      function Add_Volume
        (Config : in out Service_Definition; Vol_Str : String)
         return Parse_Result
      is
         Colon_Pos : constant Natural := Index (Vol_Str, ":");
      begin
         if Colon_Pos = 0 then
            return
              Failure
                ("Invalid volume format '"
                 & Vol_Str
                 & "': expected HOST:CONTAINER");
         end if;

         if Config.Volumes_Count >= MAX_VOLUMES_ENTRIES then
            return
              Failure
                ("Too many volumes entries (maximum "
                 & Trim (Natural'Image (MAX_VOLUMES_ENTRIES), Ada.Strings.Both)
                 & ")");
         end if;

         Config.Volumes (Config.Volumes_Count + 1) :=
           (Host      =>
              To_Unbounded_String (Vol_Str (Vol_Str'First .. Colon_Pos - 1)),
            Container =>
              To_Unbounded_String (Vol_Str (Colon_Pos + 1 .. Vol_Str'Last)));
         Config.Volumes_Count := Config.Volumes_Count + 1;
         return (Success => True, Config => Config);
      end Add_Volume;

   begin
      if not Root.Has ("service") then
         return Failure ("No [service] section found in config");
      end if;

      declare
         Service_Table : constant TOML_Value := Root.Get ("service");
      begin
         if Service_Table.Kind /= TOML_Table then
            return Failure ("Invalid [service] section: expected table");
         end if;

         declare
            Entries : constant TOML.Table_Entry_Array :=
              Service_Table.Iterate_On_Table;
         begin
            if Entries'Length = 0 then
               return Failure ("No service definitions found");
            end if;

            declare
               Service_Name  : constant String :=
                 To_String (Entries (Entries'First).Key);
               Service_Value : constant TOML_Value :=
                 Entries (Entries'First).Value;
               Config        : Service_Definition;
            begin
               if Service_Value.Kind /= TOML_Table then
                  return
                    Failure ("Invalid service definition: expected table");
               end if;

               Config.Service_Name := To_Unbounded_String (Service_Name);

               if not Service_Value.Has ("image") then
                  return
                    Failure
                      ("Missing required field 'image' in service definition");
               end if;

               if Service_Value.Get ("image").Kind /= TOML_String then
                  return Failure ("Invalid image field: expected string");
               end if;

               Config.Image :=
                 To_Unbounded_String (Service_Value.Get ("image").As_String);

               if Service_Value.Has ("env") then
                  declare
                     Env_Table : constant TOML_Value :=
                       Service_Value.Get ("env");
                  begin
                     if Env_Table.Kind /= TOML_Table then
                        return Failure ("Invalid env field: expected table");
                     end if;

                     declare
                        Env_Entries : constant TOML.Table_Entry_Array :=
                          Env_Table.Iterate_On_Table;
                     begin
                        for Env_Item of Env_Entries loop
                           if Config.Env_Count >= MAX_ENV_ENTRIES then
                              return
                                Failure
                                  ("Too many env entries (maximum "
                                   & Trim
                                       (Natural'Image (MAX_ENV_ENTRIES),
                                        Ada.Strings.Both)
                                   & ")");
                           end if;

                           if Env_Item.Value.Kind /= TOML_String then
                              return
                                Failure ("Invalid env entry: expected string");
                           end if;

                           Config.Env (Config.Env_Count + 1) :=
                             (Key   => Env_Item.Key,
                              Value =>
                                To_Unbounded_String
                                  (Env_Item.Value.As_String));
                           Config.Env_Count := Config.Env_Count + 1;
                        end loop;
                     end;
                  end;
               end if;

               if Service_Value.Has ("ports") then
                  declare
                     Ports_Array : constant TOML_Value :=
                       Service_Value.Get ("ports");
                  begin
                     if Ports_Array.Kind /= TOML_Array then
                        return Failure ("Invalid ports field: expected array");
                     end if;

                     for I in 1 .. Ports_Array.Length loop
                        declare
                           Port_Value : constant TOML_Value :=
                             Ports_Array.Item (I);
                        begin
                           if Port_Value.Kind /= TOML_String then
                              return
                                Failure
                                  ("Invalid port entry: expected string");
                           end if;

                           declare
                              Result : constant Parse_Result :=
                                Add_Port (Config, Port_Value.As_String);
                           begin
                              if not Result.Success then
                                 return Result;
                              end if;
                           end;
                        end;
                     end loop;
                  end;
               end if;

               if Service_Value.Has ("volumes") then
                  declare
                     Volumes_Array : constant TOML_Value :=
                       Service_Value.Get ("volumes");
                  begin
                     if Volumes_Array.Kind /= TOML_Array then
                        return
                          Failure ("Invalid volumes field: expected array");
                     end if;

                     for I in 1 .. Volumes_Array.Length loop
                        declare
                           Volume_Value : constant TOML_Value :=
                             Volumes_Array.Item (I);
                        begin
                           if Volume_Value.Kind /= TOML_String then
                              return
                                Failure
                                  ("Invalid volume entry: expected string");
                           end if;

                           declare
                              Result : constant Parse_Result :=
                                Add_Volume (Config, Volume_Value.As_String);
                           begin
                              if not Result.Success then
                                 return Result;
                              end if;
                           end;
                        end;
                     end loop;
                  end;
               end if;

               return Validate (Config);
            end;
         end;
      end;
   end Extract_Service_Config;

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
            return
              (Success => False, Message => To_Unbounded_String (Error_Msg));
         end;
      end if;

      return Extract_Service_Config (Load_Result.Value);
   end Parse;

   ------------------
   -- Parse_Content --
   ------------------

   function Parse_Content (Content : String) return Parse_Result is
      Load_Result : constant TOML.Read_Result := TOML.Load_String (Content);
   begin
      if not Load_Result.Success then
         declare
            Error_Msg : constant String := TOML.Format_Error (Load_Result);
         begin
            return
              (Success => False, Message => To_Unbounded_String (Error_Msg));
         end;
      end if;

      return Extract_Service_Config (Load_Result.Value);
   end Parse_Content;

   --------------
   -- Validate --
   --------------

   function Validate (Config : Service_Definition) return Parse_Result is
   begin
      -- Image must not be empty
      if Config.Image = Null_Unbounded_String then
         return
           (Success => False,
            Message => To_Unbounded_String ("Image must not be empty"));
      end if;

      -- Volume host/container paths must not be empty
      for I in 1 .. Config.Volumes_Count loop
         if Config.Volumes (I).Host = Null_Unbounded_String then
            return
              (Success => False,
               Message =>
                 To_Unbounded_String ("Volume host path must not be empty"));
         end if;
         if Config.Volumes (I).Container = Null_Unbounded_String then
            return
              (Success => False,
               Message =>
                 To_Unbounded_String
                   ("Volume container path must not be empty"));
         end if;
      end loop;

      return (Success => True, Config => Config);
   end Validate;

end Podmander.Config.Parser;
