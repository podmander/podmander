--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  JSON serialization and deserialization utilities for Service_Version
--  fields (env, ports, volumes). These are stored as JSON TEXT columns
--  in the service_versions SQLite table.
--
--  This package also provides generic JSON value extraction helpers
--  (Find_String_Value, Find_Int_Value) used by the repository layer.

package Podmander.Controller.Service.Json_Utils is

   Parse_Error : exception;

   function Env_Array_To_JSON (Arr : Env_Array; Count : Natural) return String;
   -- Serialize the first Count elements of Arr as a JSON array of objects.

   function Port_Array_To_JSON
     (Arr : Port_Array; Count : Natural) return String;
   -- Serialize the first Count elements of Arr as a JSON array of objects.

   function Volume_Array_To_JSON
     (Arr : Volume_Array; Count : Natural) return String;
   -- Serialize the first Count elements of Arr as a JSON array of objects.

   function Find_String_Value (S : String; Key : String) return String;
   -- Parse the first occurrence of "key":"value" from JSON object string S.
   -- Raises Parse_Error if parsing fails or the field is missing.

   function Find_Int_Value (S : String; Key : String) return Integer;
   -- Parse the first occurrence of "key":<integer> from JSON object string S.
   -- Raises Parse_Error if parsing fails or the field is missing.

   procedure Parse_Env_Array
     (JSON_Str : String; Arr : in out Env_Array; Count : out Natural);
   -- Parse a JSON array of {"key":"...","value":"..."} objects into Arr.
   -- Count is set to the number of objects parsed.

   procedure Parse_Port_Array
     (JSON_Str : String; Arr : in out Port_Array; Count : out Natural);
   -- Parse a JSON array of {"host":<int>,"container":<int>} objects into Arr.
   -- Count is set to the number of objects parsed.

   procedure Parse_Volume_Array
     (JSON_Str : String; Arr : in out Volume_Array; Count : out Natural);
   -- Parse a JSON array of {"host":"...","container":"..."} objects into Arr.
   -- Count is set to the number of objects parsed.

end Podmander.Controller.Service.Json_Utils;
