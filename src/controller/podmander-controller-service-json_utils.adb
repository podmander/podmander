--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with GNATCOLL.JSON;

use type GNATCOLL.JSON.JSON_Value_Type;

package body Podmander.Controller.Service.Json_Utils is

   use Ada.Strings.Unbounded;

   function Parse (S : String) return GNATCOLL.JSON.JSON_Value is
      Result : constant GNATCOLL.JSON.Read_Result := GNATCOLL.JSON.Read (S);
   begin
      if Result.Success then
         return Result.Value;
      else
         raise Parse_Error with "malformed JSON";
      end if;
   end Parse;

   function Find_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Key : String)
      return GNATCOLL.JSON.JSON_Value is
   begin
      if Obj.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         raise Parse_Error with "expected JSON object";
      end if;

      if not Obj.Has_Field (Key) then
         raise Parse_Error with "missing field '" & Key & "'";
      end if;
      return Obj.Get (Key);
   end Find_Field;

   function String_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Key : String) return String
   is
      Val : constant GNATCOLL.JSON.JSON_Value := Find_Field (Obj, Key);
   begin
      if Val.Kind /= GNATCOLL.JSON.JSON_String_Type then
         raise Parse_Error with "field '" & Key & "' is not a string";
      end if;
      return Val.Get;
   end String_Field;

   function Integer_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Key : String) return Integer
   is
      Val : constant GNATCOLL.JSON.JSON_Value := Find_Field (Obj, Key);
   begin
      if Val.Kind /= GNATCOLL.JSON.JSON_Int_Type then
         raise Parse_Error with "field '" & Key & "' is not an integer";
      end if;
      return Val.Get;
   end Integer_Field;

   function Positive_Field
     (Obj : GNATCOLL.JSON.JSON_Value; Key : String) return Positive is
   begin
      return Positive (Integer_Field (Obj, Key));
   exception
      when Constraint_Error =>
         raise Parse_Error
           with "field '" & Key & "' is not a positive integer";
   end Positive_Field;

   function Make_Object return GNATCOLL.JSON.JSON_Value
   is (GNATCOLL.JSON.Create_Object);

   function Root_Array (S : String) return GNATCOLL.JSON.JSON_Array is
      Obj : constant GNATCOLL.JSON.JSON_Value := Parse (S);
   begin
      if Obj.Kind /= GNATCOLL.JSON.JSON_Array_Type then
         raise Parse_Error with "expected JSON array";
      end if;
      return Obj.Get;
   end Root_Array;

   function Env_Array_To_JSON (Arr : Env_Array; Count : Natural) return String
   is
      Items : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      for I in 1 .. Count loop
         declare
            Item : constant GNATCOLL.JSON.JSON_Value := Make_Object;
         begin
            Item.Set_Field ("key", To_String (Arr (I).Key));
            Item.Set_Field ("value", To_String (Arr (I).Value));
            GNATCOLL.JSON.Append (Items, Item);
         end;
      end loop;
      return GNATCOLL.JSON.Write (GNATCOLL.JSON.Create (Items));
   end Env_Array_To_JSON;

   function Port_Array_To_JSON
     (Arr : Port_Array; Count : Natural) return String
   is
      Items : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      for I in 1 .. Count loop
         declare
            Item : constant GNATCOLL.JSON.JSON_Value := Make_Object;
         begin
            Item.Set_Field ("host", Integer (Arr (I).Host));
            Item.Set_Field ("container", Integer (Arr (I).Container));
            GNATCOLL.JSON.Append (Items, Item);
         end;
      end loop;
      return GNATCOLL.JSON.Write (GNATCOLL.JSON.Create (Items));
   end Port_Array_To_JSON;

   function Volume_Array_To_JSON
     (Arr : Volume_Array; Count : Natural) return String
   is
      Items : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      for I in 1 .. Count loop
         declare
            Item : constant GNATCOLL.JSON.JSON_Value := Make_Object;
         begin
            Item.Set_Field ("host", To_String (Arr (I).Host));
            Item.Set_Field ("container", To_String (Arr (I).Container));
            GNATCOLL.JSON.Append (Items, Item);
         end;
      end loop;
      return GNATCOLL.JSON.Write (GNATCOLL.JSON.Create (Items));
   end Volume_Array_To_JSON;

   function Find_String_Value (S : String; Key : String) return String is
      Obj : constant GNATCOLL.JSON.JSON_Value := Parse (S);
   begin
      return String_Field (Obj, Key);
   end Find_String_Value;

   function Find_Int_Value (S : String; Key : String) return Integer is
      Obj : constant GNATCOLL.JSON.JSON_Value := Parse (S);
   begin
      return Integer_Field (Obj, Key);
   end Find_Int_Value;

   procedure Parse_Env_Array
     (JSON_Str : String; Arr : in out Env_Array; Count : out Natural)
   is
      Items : constant GNATCOLL.JSON.JSON_Array := Root_Array (JSON_Str);
   begin
      Count := 0;
      for Item of Items loop
         exit when Count = MAX_ENV_ENTRIES;
         if Item.Kind /= GNATCOLL.JSON.JSON_Object_Type then
            raise Parse_Error with "expected object in env array";
         end if;
         declare
            Obj : constant GNATCOLL.JSON.JSON_Value := Item;
         begin
            Count := Count + 1;
            Arr (Count).Key := To_Unbounded_String (String_Field (Obj, "key"));
            Arr (Count).Value :=
              To_Unbounded_String (String_Field (Obj, "value"));
         end;
      end loop;
   end Parse_Env_Array;

   procedure Parse_Port_Array
     (JSON_Str : String; Arr : in out Port_Array; Count : out Natural)
   is
      Items : constant GNATCOLL.JSON.JSON_Array := Root_Array (JSON_Str);
   begin
      Count := 0;
      for Item of Items loop
         exit when Count = MAX_PORTS_ENTRIES;
         if Item.Kind /= GNATCOLL.JSON.JSON_Object_Type then
            raise Parse_Error with "expected object in ports array";
         end if;
         declare
            Obj : constant GNATCOLL.JSON.JSON_Value := Item;
         begin
            Count := Count + 1;
            Arr (Count).Host := Positive_Field (Obj, "host");
            Arr (Count).Container := Positive_Field (Obj, "container");
         end;
      end loop;
   end Parse_Port_Array;

   procedure Parse_Volume_Array
     (JSON_Str : String; Arr : in out Volume_Array; Count : out Natural)
   is
      Items : constant GNATCOLL.JSON.JSON_Array := Root_Array (JSON_Str);
   begin
      Count := 0;
      for Item of Items loop
         exit when Count = MAX_VOLUMES_ENTRIES;
         if Item.Kind /= GNATCOLL.JSON.JSON_Object_Type then
            raise Parse_Error with "expected object in volumes array";
         end if;
         declare
            Obj : constant GNATCOLL.JSON.JSON_Value := Item;
         begin
            Count := Count + 1;
            Arr (Count).Host :=
              To_Unbounded_String (String_Field (Obj, "host"));
            Arr (Count).Container :=
              To_Unbounded_String (String_Field (Obj, "container"));
         end;
      end loop;
   end Parse_Volume_Array;

end Podmander.Controller.Service.Json_Utils;
