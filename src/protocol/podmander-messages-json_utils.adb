--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar.Formatting;
with GNATCOLL.JSON;

use type GNATCOLL.JSON.JSON_Value_Type;

package body Podmander.Messages.JSON_Utils is

   ----------
   -- Get_Kind
   ----------
   function Get_Kind (Obj : GNATCOLL.JSON.JSON_Value) return String is
   begin
      if not Obj.Has_Field (Kind_Field) then
         raise Decode_Error with "missing '" & Kind_Field & "' field";
      end if;
      return Obj.Get (Kind_Field);
   end Get_Kind;

   ----------
   -- Set_Kind
   ----------
   procedure Set_Kind (Obj : GNATCOLL.JSON.JSON_Value; Kind : String) is
   begin
      Obj.Set_Field (Kind_Field, Kind);
   end Set_Kind;

   ---------------
   -- Get_Field (String)
   ---------------
   function Get_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String) return String
   is
   begin
      if not Obj.Has_Field (Field) then
         raise Decode_Error with "missing field '" & Field & "'";
      end if;
      declare
         Val : constant GNATCOLL.JSON.JSON_Value := Obj.Get (Field);
      begin
         if Val.Kind /= GNATCOLL.JSON.JSON_String_Type then
            raise Decode_Error with "field '" & Field & "' is not a string";
         end if;
         return Val.Get;
      end;
   end Get_Field;

   ---------------
   -- Get_Field (Integer)
   ---------------
   function Get_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String) return Integer
   is
   begin
      if not Obj.Has_Field (Field) then
         raise Decode_Error with "missing field '" & Field & "'";
      end if;
      declare
         Val : constant GNATCOLL.JSON.JSON_Value := Obj.Get (Field);
      begin
         if Val.Kind /= GNATCOLL.JSON.JSON_Int_Type then
            raise Decode_Error with "field '" & Field & "' is not an integer";
         end if;
         return Val.Get;
      end;
   end Get_Field;

   ---------------
   -- Get_Field (Time)
   ---------------
   function Get_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String) return Ada.Calendar.Time
   is
      Raw : constant String := Get_Field (Obj, Field);
   begin
      return Ada.Calendar.Formatting.Value (Raw);
   exception
      when Constraint_Error =>
         raise Decode_Error with "field '" & Field & "' is not a valid timestamp";
   end Get_Field;

   ---------------
   -- Set_Field (String)
   ---------------
   procedure Set_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String; Value : String)
   is
   begin
      Obj.Set_Field (Field, Value);
   end Set_Field;

   ---------------
   -- Set_Field (Integer)
   ---------------
   procedure Set_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Field : String; Value : Integer)
   is
   begin
      Obj.Set_Field (Field, Value);
   end Set_Field;

   ---------------
   -- Set_Field (Time)
   ---------------
   procedure Set_Field
     (Obj : GNATCOLL.JSON.JSON_Value;
      Field : String;
      Value : Ada.Calendar.Time)
   is
   begin
      Obj.Set_Field (Field, Ada.Calendar.Formatting.Image (Value));
   end Set_Field;

   ----------------
   -- Encode_Code
   ----------------
   function Encode_Code
     (Code : Podmander.Messages.Result_Codes.Result_Code) return String
   is
      (Podmander.Messages.Result_Codes.Encode_Code (Code));

   ----------------
   -- Decode_Code
   ----------------
   function Decode_Code
     (S : String) return Podmander.Messages.Result_Codes.Result_Code
   is
      (Podmander.Messages.Result_Codes.Decode_Code (S));

end Podmander.Messages.JSON_Utils;