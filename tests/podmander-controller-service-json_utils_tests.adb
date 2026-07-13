--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with Podmander.Config;
with Podmander.Controller.Service.Json_Utils;

package body Podmander.Controller.Service.Json_Utils_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type GNATCOLL.JSON.JSON_Value_Type;

   package Json renames Podmander.Controller.Service.Json_Utils;

   type Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Service.Json_Utils"));

   overriding
   procedure Register_Tests (T : in out Test_Case);

   procedure Test_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Env           :
        Podmander.Config.Env_Array (1 .. Podmander.Config.MAX_ENV_ENTRIES);
      Ports         :
        Podmander.Config.Port_Array (1 .. Podmander.Config.MAX_PORTS_ENTRIES);
      Volumes       :
        Podmander.Config.Volume_Array
          (1 .. Podmander.Config.MAX_VOLUMES_ENTRIES);
      Env_Count     : Natural;
      Ports_Count   : Natural;
      Volumes_Count : Natural;
   begin
      Env (1) :=
        (Key   => To_Unbounded_String ("FOO"),
         Value => To_Unbounded_String ("bar"));
      Env (2) :=
        (Key   => To_Unbounded_String ("QUOTE"),
         Value => To_Unbounded_String ("one ""two"" \\ three {four}"));
      Env_Count := 2;

      Ports (1) := (Host => 8080, Container => 80);
      Ports (2) := (Host => 8443, Container => 443);
      Ports_Count := 2;

      Volumes (1) :=
        (Host      => To_Unbounded_String ("/host/{data}"),
         Container => To_Unbounded_String ("/container/\\data"""));
      Volumes_Count := 1;

      declare
         Env_JSON             : constant String :=
           Json.Env_Array_To_JSON (Env, Env_Count);
         Port_JSON            : constant String :=
           Json.Port_Array_To_JSON (Ports, Ports_Count);
         Volume_JSON          : constant String :=
           Json.Volume_Array_To_JSON (Volumes, Volumes_Count);
         Parsed_Env           :
           Podmander.Config.Env_Array (1 .. Podmander.Config.MAX_ENV_ENTRIES);
         Parsed_Ports         :
           Podmander.Config.Port_Array
             (1 .. Podmander.Config.MAX_PORTS_ENTRIES);
         Parsed_Volumes       :
           Podmander.Config.Volume_Array
             (1 .. Podmander.Config.MAX_VOLUMES_ENTRIES);
         Parsed_Env_Count     : Natural;
         Parsed_Ports_Count   : Natural;
         Parsed_Volumes_Count : Natural;
      begin
         Assert
           (GNATCOLL.JSON.Read (Env_JSON).Kind = GNATCOLL.JSON.JSON_Array_Type,
            "env JSON shape");
         Assert
           (GNATCOLL.JSON.Read (Port_JSON).Kind
            = GNATCOLL.JSON.JSON_Array_Type,
            "port JSON shape");
         Assert
           (GNATCOLL.JSON.Read (Volume_JSON).Kind
            = GNATCOLL.JSON.JSON_Array_Type,
            "volume JSON shape");
         Json.Parse_Env_Array (Env_JSON, Parsed_Env, Parsed_Env_Count);
         Json.Parse_Port_Array (Port_JSON, Parsed_Ports, Parsed_Ports_Count);
         Json.Parse_Volume_Array
           (Volume_JSON, Parsed_Volumes, Parsed_Volumes_Count);

         Assert (Parsed_Env_Count = Env_Count, "env count round-trip");
         Assert (Parsed_Ports_Count = Ports_Count, "ports count round-trip");
         Assert
           (Parsed_Volumes_Count = Volumes_Count, "volumes count round-trip");
         Assert
           (To_String (Parsed_Env (2).Value) = "one ""two"" \\ three {four}",
            "escaped env value round-trip");
         Assert (Parsed_Ports (2).Host = 8443, "ports round-trip");
         Assert
           (To_String (Parsed_Volumes (1).Container) = "/container/\\data""",
            "escaped volume round-trip");
         Assert (To_String (Parsed_Env (1).Key) = "FOO", "env key round-trip");
      end;
   end Test_Round_Trip;

   procedure Test_Control_Character_Serialization
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Env : Podmander.Config.Env_Array (1 .. 1);
   begin
      Env (1) :=
        (Key   => To_Unbounded_String ("CTRL"),
         Value => To_Unbounded_String ("A" & ASCII.HT & "B" & ASCII.LF & "C"));
      declare
         Env_JSON : constant String := Json.Env_Array_To_JSON (Env, 1);
         Parsed   : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Read (Env_JSON);
      begin
         Assert
           (Parsed.Kind = GNATCOLL.JSON.JSON_Array_Type,
            "control JSON array shape");
         declare
            Actual : constant GNATCOLL.JSON.UTF8_String :=
              GNATCOLL.JSON.Get
                (GNATCOLL.JSON.Get (Parsed.Get, 1),
                 GNATCOLL.JSON.UTF8_String'("value"));
         begin
            Assert
              (Actual = "A" & ASCII.HT & "B" & ASCII.LF & "C",
               "control chars preserved");
         end;
      end;
   end Test_Control_Character_Serialization;

   procedure Test_Brace_Strings_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Volumes : Podmander.Config.Volume_Array (1 .. 2);
   begin
      Volumes (1) :=
        (Host      => To_Unbounded_String ("{unmatched"),
         Container => To_Unbounded_String ("brace}"));
      Volumes (2) :=
        (Host      => To_Unbounded_String ("left{right}"),
         Container => To_Unbounded_String ("nested {{}} braces"));
      declare
         JSON_Text : constant String := Json.Volume_Array_To_JSON (Volumes, 2);
         Parsed    :
           Podmander.Config.Volume_Array
             (1 .. Podmander.Config.MAX_VOLUMES_ENTRIES);
         Count     : Natural;
      begin
         Assert
           (GNATCOLL.JSON.Read (JSON_Text).Kind
            = GNATCOLL.JSON.JSON_Array_Type,
            "brace JSON array shape");
         Json.Parse_Volume_Array (JSON_Text, Parsed, Count);
         Assert (Count = 2, "brace round-trip count");
         Assert
           (To_String (Parsed (1).Host) = "{unmatched",
            "brace host preserved");
         Assert
           (To_String (Parsed (2).Container) = "nested {{}} braces",
            "nested brace preserved");
      end;
   end Test_Brace_Strings_Round_Trip;

   procedure Test_Malformed_Array_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Parsed :
        Podmander.Config.Env_Array (1 .. Podmander.Config.MAX_ENV_ENTRIES);
      Count  : Natural;
   begin
      Json.Parse_Env_Array ("not json", Parsed, Count);
      Assert (False, "expected Parse_Error for malformed array JSON");
   exception
      when Json.Parse_Error =>
         null;
   end Test_Malformed_Array_Failure;

   procedure Test_Wrong_Top_Level_Shape_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Parsed :
        Podmander.Config.Port_Array (1 .. Podmander.Config.MAX_PORTS_ENTRIES);
      Count  : Natural;
   begin
      Json.Parse_Port_Array ("{""host"":1}", Parsed, Count);
      Assert (False, "expected Parse_Error for wrong top-level shape");
   exception
      when Json.Parse_Error =>
         null;
   end Test_Wrong_Top_Level_Shape_Failure;

   procedure Test_Extra_Array_Items_Are_Ignored
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Arr       :
        Podmander.Config.Env_Array (1 .. Podmander.Config.MAX_ENV_ENTRIES);
      Count     : Natural;
      JSON_Text : constant String :=
        "[{""key"":""A"",""value"":""1""},{""key"":""B"",""value"":""2""}]";
   begin
      Json.Parse_Env_Array (JSON_Text, Arr, Count);
      Assert (Count = 2, "array parsing should keep bounded items");
      Assert (To_String (Arr (1).Key) = "A", "first item retained");
      Assert (To_String (Arr (2).Key) = "B", "second item retained");
   end Test_Extra_Array_Items_Are_Ignored;

   procedure Test_Parse_Failure (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      declare
         Ignored : constant String :=
           Json.Find_String_Value ("not json", "key");
         pragma Unreferenced (Ignored);
      begin
         Assert (False, "expected Parse_Error for malformed JSON");
      end;
   exception
      when Json.Parse_Error =>
         null;
   end Test_Parse_Failure;

   procedure Test_Missing_Field_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      declare
         Ignored : constant String :=
           Json.Find_String_Value ("{""other"":""value""}", "key");
         pragma Unreferenced (Ignored);
      begin
         Assert (False, "expected Parse_Error for missing field");
      end;
   exception
      when Json.Parse_Error =>
         null;
   end Test_Missing_Field_Failure;

   procedure Test_Invalid_Field_Type_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      declare
         Ignored : constant Integer :=
           Json.Find_Int_Value ("{""host"":""bad""}", "host");
         pragma Unreferenced (Ignored);
      begin
         Assert (False, "expected Parse_Error for invalid integer field");
      end;
   exception
      when Json.Parse_Error =>
         null;
   end Test_Invalid_Field_Type_Failure;

   procedure Test_Invalid_Port_Value_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Parsed :
        Podmander.Config.Port_Array (1 .. Podmander.Config.MAX_PORTS_ENTRIES);
      Count  : Natural;
   begin
      Json.Parse_Port_Array ("[{""host"":0,""container"":80}]", Parsed, Count);
      Assert (False, "expected Parse_Error for non-positive port");
   exception
      when Json.Parse_Error =>
         null;
   end Test_Invalid_Port_Value_Failure;

   procedure Test_Port_Above_Range_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Parsed :
        Podmander.Config.Port_Array (1 .. Podmander.Config.MAX_PORTS_ENTRIES);
      Count  : Natural;
   begin
      Json.Parse_Port_Array
        ("[{""host"":65536,""container"":80}]", Parsed, Count);
      Assert (False, "expected Parse_Error for out-of-range port");
   exception
      when Json.Parse_Error =>
         null;
   end Test_Port_Above_Range_Failure;

   procedure Test_Negative_Container_Port_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Parsed :
        Podmander.Config.Port_Array (1 .. Podmander.Config.MAX_PORTS_ENTRIES);
      Count  : Natural;
   begin
      Json.Parse_Port_Array
        ("[{""host"":80,""container"":-1}]", Parsed, Count);
      Assert (False, "expected Parse_Error for negative container port");
   exception
      when Json.Parse_Error =>
         null;
   end Test_Negative_Container_Port_Failure;

   procedure Test_Port_Boundary_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Ports : constant Podmander.Config.Port_Array (1 .. 1) :=
        [1 => (Host => 1, Container => 65_535)];
      Parsed :
        Podmander.Config.Port_Array (1 .. Podmander.Config.MAX_PORTS_ENTRIES);
      Count  : Natural;
   begin
      Json.Parse_Port_Array (Json.Port_Array_To_JSON (Ports, 1), Parsed, Count);
      Assert (Count = 1, "one port should survive round-trip");
      Assert (Parsed (1).Host = 1, "host lower boundary should survive");
      Assert
        (Parsed (1).Container = 65_535,
         "container upper boundary should survive");
   end Test_Port_Boundary_Round_Trip;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Round_Trip'Access,
         "Round-trip env/ports/volumes with escaped strings");
      Register_Routine
        (T,
         Test_Control_Character_Serialization'Access,
         "Control characters survive JSON serialization");
      Register_Routine
        (T,
         Test_Brace_Strings_Round_Trip'Access,
         "Braces in strings round-trip through array parsing");
      Register_Routine
        (T,
         Test_Malformed_Array_Failure'Access,
         "Malformed array JSON raises Parse_Error");
      Register_Routine
        (T,
         Test_Wrong_Top_Level_Shape_Failure'Access,
         "Wrong top-level JSON shape raises Parse_Error");
      Register_Routine
        (T,
         Test_Extra_Array_Items_Are_Ignored'Access,
         "Extra array items beyond capacity are ignored");
      Register_Routine
        (T, Test_Parse_Failure'Access, "Malformed JSON raises Parse_Error");
      Register_Routine
        (T,
         Test_Missing_Field_Failure'Access,
         "Missing field raises Parse_Error");
      Register_Routine
        (T,
         Test_Invalid_Field_Type_Failure'Access,
         "Invalid field type raises Parse_Error");
      Register_Routine
        (T,
         Test_Invalid_Port_Value_Failure'Access,
         "Invalid port value raises Parse_Error");
      Register_Routine
        (T,
         Test_Port_Above_Range_Failure'Access,
         "Port above range raises Parse_Error");
      Register_Routine
        (T,
         Test_Negative_Container_Port_Failure'Access,
         "Negative container port raises Parse_Error");
      Register_Routine
        (T,
         Test_Port_Boundary_Round_Trip'Access,
         "Port boundary values round-trip through JSON");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Test_Case;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Service.Json_Utils_Tests;
