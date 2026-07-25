--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Fixed;
with Ada.Characters.Handling;

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

      function Port_Number_Image (Value : Long_Long_Integer) return String is
      begin
         return Trim (Long_Long_Integer'Image (Value), Ada.Strings.Both);
      end Port_Number_Image;

      function Add_Port
        (Config : in out Service_Definition;
         Host   : Port_Number;
         Target : Port_Number) return Parse_Result is
      begin
         if Config.Ports_Count >= MAX_PORTS_ENTRIES then
            return
              Failure
                ("Too many ports entries (maximum "
                 & Trim (Natural'Image (MAX_PORTS_ENTRIES), Ada.Strings.Both)
                 & ")");
         end if;

         Config.Ports (Config.Ports_Count + 1) :=
           (Host => Host, Container => Target);
         Config.Ports_Count := Config.Ports_Count + 1;
         return (Success => True, Config => Config);
      end Add_Port;

      function Add_Named_Port
        (Config : in out Service_Definition; Name : String; Table : TOML_Value)
         return Parse_Result
      is
         function Valid_Name return Boolean is
         begin
            if Name'Length = 0 or else Name (Name'First) not in 'a' .. 'z' then
               return False;
            end if;
            for C of Name loop
               if C not in 'a' .. 'z'
                 and then C not in '0' .. '9'
                 and then C /= '-'
               then
                  return False;
               end if;
            end loop;
            return True;
         end Valid_Name;
      begin
         if not Valid_Name then
            return Failure ("Invalid named port name '" & Name & "'");
         end if;
         for Item of Table.Iterate_On_Table loop
            if Item.Key /= To_Unbounded_String ("host")
              and then Item.Key /= To_Unbounded_String ("container")
            then
               return
                 Failure
                   ("Unknown named port field '" & To_String (Item.Key) & "'");
            end if;
         end loop;
         if not Table.Has ("host") then
            return Failure ("Invalid named port '" & Name & "': missing host");
         end if;
         if not Table.Has ("container") then
            return
              Failure ("Invalid named port '" & Name & "': missing container");
         end if;
         declare
            Host_Value       : constant TOML_Value := Table.Get ("host");
            Container_Value  : constant TOML_Value := Table.Get ("container");
            Host_Number      : Long_Long_Integer;
            Container_Number : Long_Long_Integer;
         begin
            if Host_Value.Kind /= TOML_Integer then
               return
                 Failure
                   ("Invalid named port '"
                    & Name
                    & "': host expected integer");
            end if;
            if Container_Value.Kind /= TOML_Integer then
               return
                 Failure
                   ("Invalid named port '"
                    & Name
                    & "': container expected integer");
            end if;
            Host_Number := Long_Long_Integer (Host_Value.As_Integer);
            Container_Number := Long_Long_Integer (Container_Value.As_Integer);
            if Host_Number not in MIN_PORT .. MAX_PORT then
               return Invalid_Port_Number (Port_Number_Image (Host_Number));
            end if;
            if Container_Number not in MIN_PORT .. MAX_PORT then
               return
                 Invalid_Port_Number (Port_Number_Image (Container_Number));
            end if;
            if Config.Named_Ports_Count >= MAX_NAMED_PORTS_ENTRIES then
               return
                 Failure
                   ("Too many named ports entries (maximum "
                    & Trim
                        (Natural'Image (MAX_NAMED_PORTS_ENTRIES),
                         Ada.Strings.Both)
                    & ")");
            end if;
            Config.Named_Ports_Count := Config.Named_Ports_Count + 1;
            Config.Named_Ports (Config.Named_Ports_Count) :=
              (Name      => To_Unbounded_String (Name),
               Host      => Port_Number (Host_Number),
               Container => Port_Number (Container_Number));
            return (Success => True, Config => Config);
         end;
      end Add_Named_Port;

      function Normalize_Host
        (Host : String; Result : out String) return Boolean
      is
         Dot_Count    : Natural := 0;
         Label_Start  : Positive := Host'First;
         Has_Letter   : Boolean := False;
         Label_Length : Natural := 0;
      begin
         if Host'Length = 0 or else Host'Length > 253 then
            return False;
         end if;
         for I in Host'Range loop
            if Host (I) not in 'a' .. 'z'
              and then Host (I) not in 'A' .. 'Z'
              and then Host (I) not in '0' .. '9'
              and then Host (I) /= '-'
              and then Host (I) /= '.'
            then
               return False;
            end if;
            Has_Letter :=
              Has_Letter
              or else Host (I) in 'a' .. 'z'
              or else Host (I) in 'A' .. 'Z';
            if Host (I) = '.' then
               if I = Label_Start
                 or else Label_Length > 63
                 or else Host (I - 1) = '-'
                 or else Host (Label_Start) = '-'
               then
                  return False;
               end if;
               Dot_Count := Dot_Count + 1;
               Label_Start := I + 1;
               Label_Length := 0;
            else
               if Label_Length = 0 and then Host (I) = '-' then
                  return False;
               end if;
               Label_Length := Label_Length + 1;
            end if;
         end loop;
         if Dot_Count = 0
           or else not Has_Letter
           or else Label_Start > Host'Last
           or else Label_Length > 63
           or else Host (Host'Last) = '-'
         then
            return False;
         end if;
         Result := Host;
         for I in Result'Range loop
            Result (I) := Ada.Characters.Handling.To_Lower (Result (I));
         end loop;
         return True;
      end Normalize_Host;

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

            return Add_Port (Config, Host_Port, Container_Port);
         end;
      end Add_Port;

      function Add_Port
        (Config : in out Service_Definition; Port_Table : TOML_Value)
         return Parse_Result is
      begin
         for Item of Port_Table.Iterate_On_Table loop
            if Item.Key /= To_Unbounded_String ("host")
              and then Item.Key /= To_Unbounded_String ("container")
            then
               return
                 Failure ("Unknown port field '" & To_String (Item.Key) & "'");
            end if;
         end loop;
         if not Port_Table.Has ("host") then
            return Failure ("Invalid port entry: missing host");
         end if;

         if not Port_Table.Has ("container") then
            return Failure ("Invalid port entry: missing container");
         end if;

         declare
            Host_Value      : constant TOML_Value := Port_Table.Get ("host");
            Container_Value : constant TOML_Value :=
              Port_Table.Get ("container");
         begin
            if Host_Value.Kind /= TOML_Integer then
               return Failure ("Invalid port entry: host expected integer");
            end if;

            if Container_Value.Kind /= TOML_Integer then
               return
                 Failure ("Invalid port entry: container expected integer");
            end if;

            declare
               Host_Number      : constant Long_Long_Integer :=
                 Long_Long_Integer (Host_Value.As_Integer);
               Container_Number : constant Long_Long_Integer :=
                 Long_Long_Integer (Container_Value.As_Integer);
               Host_Port        : Port_Number := Port_Number'First;
               Container_Port   : Port_Number := Port_Number'First;
            begin
               begin
                  Host_Port := Port_Number (Host_Number);
               exception
                  when Constraint_Error =>
                     return
                       Invalid_Port_Number (Port_Number_Image (Host_Number));
               end;

               begin
                  Container_Port := Port_Number (Container_Number);
               exception
                  when Constraint_Error =>
                     return
                       Invalid_Port_Number
                         (Port_Number_Image (Container_Number));
               end;

               return Add_Port (Config, Host_Port, Container_Port);
            end;
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

               for Item of Service_Value.Iterate_On_Table loop
                  if Item.Key /= To_Unbounded_String ("image")
                    and then Item.Key /= To_Unbounded_String ("env")
                    and then Item.Key /= To_Unbounded_String ("ports")
                    and then Item.Key /= To_Unbounded_String ("volumes")
                    and then Item.Key /= To_Unbounded_String ("description")
                    and then Item.Key /= To_Unbounded_String ("wanted_by")
                    and then Item.Key /= To_Unbounded_String ("ingress")
                  then
                     return
                       Failure
                         ("Unknown service field '"
                          & To_String (Item.Key)
                          & "'");
                  end if;
               end loop;

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
                     if Ports_Array.Kind = TOML_Table then
                        for Item of Ports_Array.Iterate_On_Table loop
                           if Item.Value.Kind /= TOML_Table then
                              return
                                Failure
                                  ("Invalid named port '"
                                   & To_String (Item.Key)
                                   & "': expected table");
                           end if;
                           declare
                              Result : constant Parse_Result :=
                                Add_Named_Port
                                  (Config, To_String (Item.Key), Item.Value);
                           begin
                              if not Result.Success then
                                 return Result;
                              end if;
                           end;
                        end loop;
                     elsif Ports_Array.Kind /= TOML_Array then
                        return
                          Failure
                            ("Invalid ports field: expected array or table");
                     else
                        for I in 1 .. Ports_Array.Length loop
                           declare
                              Port_Value : constant TOML_Value :=
                                Ports_Array.Item (I);
                           begin
                              if Port_Value.Kind = TOML_String then
                                 declare
                                    Result : constant Parse_Result :=
                                      Add_Port (Config, Port_Value.As_String);
                                 begin
                                    if not Result.Success then
                                       return Result;
                                    end if;
                                 end;
                              elsif Port_Value.Kind = TOML_Table then
                                 declare
                                    Result : constant Parse_Result :=
                                      Add_Port (Config, Port_Value);
                                 begin
                                    if not Result.Success then
                                       return Result;
                                    end if;
                                 end;
                              else
                                 return
                                   Failure
                                     ("Invalid port entry: expected string or table");
                              end if;
                           end;
                        end loop;
                     end if;
                  end;
               end if;

               if Service_Value.Has ("ingress") then
                  if Config.Ports_Count > 0 then
                     return Failure ("Ingress requires named ports table");
                  end if;
                  declare
                     Ingress_Table : constant TOML_Value :=
                       Service_Value.Get ("ingress");
                  begin
                     if Ingress_Table.Kind /= TOML_Table then
                        return
                          Failure ("Invalid ingress field: expected table");
                     end if;
                     for Item of Ingress_Table.Iterate_On_Table loop
                        if Item.Key /= To_Unbounded_String ("host")
                          and then Item.Key /= To_Unbounded_String ("port")
                        then
                           return
                             Failure
                               ("Unknown ingress field '"
                                & To_String (Item.Key)
                                & "'");
                        end if;
                     end loop;
                     if not Ingress_Table.Has ("host") then
                        return Failure ("Invalid ingress: missing host");
                     end if;
                     if not Ingress_Table.Has ("port") then
                        return Failure ("Invalid ingress: missing port");
                     end if;
                     declare
                        Host_Value : constant TOML_Value :=
                          Ingress_Table.Get ("host");
                        Port_Value : constant TOML_Value :=
                          Ingress_Table.Get ("port");
                        Host_Text  : constant String :=
                          (if Host_Value.Kind = TOML_String
                           then Host_Value.As_String
                           else "");
                        Normalized : String (Host_Text'Range) := Host_Text;
                        Port_Name  : constant String :=
                          (if Port_Value.Kind = TOML_String
                           then Port_Value.As_String
                           else "");
                        Found      : Boolean := False;
                     begin
                        if Host_Value.Kind /= TOML_String then
                           return
                             Failure ("Invalid ingress host: expected string");
                        end if;
                        if Port_Value.Kind /= TOML_String then
                           return
                             Failure ("Invalid ingress port: expected string");
                        end if;
                        if not Normalize_Host (Host_Text, Normalized) then
                           return
                             Failure
                               ("Invalid ingress host '"
                                & Host_Text
                                & "': expected DNS hostname");
                        end if;
                        for I in 1 .. Config.Named_Ports_Count loop
                           Found :=
                             Found
                             or else To_String (Config.Named_Ports (I).Name)
                                     = Port_Name;
                        end loop;
                        if not Found then
                           return
                             Failure
                               ("Invalid ingress port '"
                                & Port_Name
                                & "': undeclared named port");
                        end if;
                        Config.Ingress :=
                          (Host      => To_Unbounded_String (Normalized),
                           Port_Name => To_Unbounded_String (Port_Name));
                     end;
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
      function Duplicate_Host_Port (Host : Port_Number) return Parse_Result is
      begin
         return
           (Success => False,
            Message =>
              To_Unbounded_String
                ("Duplicate host port "
                 & Trim (Port_Number'Image (Host), Ada.Strings.Both)
                 & " in candidate service version"));
      end Duplicate_Host_Port;
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

      for I in 1 .. Config.Named_Ports_Count loop
         for J in I + 1 .. Config.Named_Ports_Count loop
            if Config.Named_Ports (I).Host = Config.Named_Ports (J).Host then
               return Duplicate_Host_Port (Config.Named_Ports (I).Host);
            end if;
         end loop;
         for J in 1 .. Config.Ports_Count loop
            if Config.Named_Ports (I).Host = Config.Ports (J).Host then
               return Duplicate_Host_Port (Config.Named_Ports (I).Host);
            end if;
         end loop;
      end loop;

      for I in 1 .. Config.Ports_Count loop
         for J in I + 1 .. Config.Ports_Count loop
            if Config.Ports (I).Host = Config.Ports (J).Host then
               return Duplicate_Host_Port (Config.Ports (I).Host);
            end if;
         end loop;
      end loop;

      return (Success => True, Config => Config);
   end Validate;

end Podmander.Config.Parser;
