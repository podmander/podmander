--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with GNATCOLL.JSON;
with Podmander.Messages.Result_Codes;

package Podmander.Messages.JSON_Utils is

   Kind_Field : constant String := "kind";
   --  JSON field name used for message type dispatch

   --  Extract the "kind" field from a parsed JSON object.
   --  Raises Decode_Error if the field is missing.
   function Get_Kind (Obj : GNATCOLL.JSON.JSON_Value) return String;

   --  Set the "kind" field on a JSON object.
   procedure Set_Kind (Obj : GNATCOLL.JSON.JSON_Value; Kind : String);

   --  Extract a string field from a JSON object.
   --  Raises Decode_Error if the field is missing or not a string.
   function Get_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String) return String;

   --  Extract an integer field from a JSON object.
   --  Raises Decode_Error if the field is missing or not an integer.
   function Get_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String) return Integer;

   --  Extract a timestamp field from a JSON object.
   --  Parses the string via Ada.Calendar.Formatting.Value.
   --  Raises Decode_Error if the field is missing or unparseable.
   function Get_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String) return Ada.Calendar.Time;

   --  Set a string field on a JSON object.
   procedure Set_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String; Value : String);

   --  Set an integer field on a JSON object.
   procedure Set_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String; Value : Integer);

   --  Set a timestamp field on a JSON object.
   --  Formats via Ada.Calendar.Formatting.Image and stores as a string.
   procedure Set_Field
     (Obj   : GNATCOLL.JSON.JSON_Value;
      Field : String;
      Value : Ada.Calendar.Time);

   --  Encode a Result_Code to its JSON string value.
   function Encode_Code
     (Code : Podmander.Messages.Result_Codes.Result_Code) return String;

   --  Decode a Result_Code from its JSON string value.
   --  Raises Decode_Error for unknown codes.
   function Decode_Code
     (S : String) return Podmander.Messages.Result_Codes.Result_Code;

end Podmander.Messages.JSON_Utils;
