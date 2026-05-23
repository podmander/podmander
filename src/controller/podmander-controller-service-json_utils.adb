--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Podmander.Config;

package body Podmander.Controller.Service.Json_Utils is

   use Ada.Strings.Unbounded;
   use Podmander.Config;

   -----------------------
   -- JSON serialization
   -----------------------

   function Escape_JSON (S : String) return String is
      Result : Unbounded_String;
   begin
      for C of S loop
         case C is
            when '"'                   =>
               Append (Result, "\""");

            when '\'                   =>
               Append (Result, "\\");

            when ASCII.NUL .. ASCII.US =>
               null;

            when others                =>
               Append (Result, C);
         end case;
      end loop;
      return To_String (Result);
   end Escape_JSON;

   function Env_Array_To_JSON (Arr : Env_Array; Count : Natural) return String is
      Result : Unbounded_String;
      First  : Boolean := True;
   begin
      Append (Result, "[");
      for I in 1 .. Count loop
         if First then
            First := False;
         else
            Append (Result, ",");
         end if;
         Append (Result, "{""key"":""");
         Append (Result, Escape_JSON (To_String (Arr (I).Key)));
         Append (Result, """,""value"":""");
         Append (Result, Escape_JSON (To_String (Arr (I).Value)));
         Append (Result, """}");
      end loop;
      Append (Result, "]");
      return To_String (Result);
   end Env_Array_To_JSON;

   function Port_Array_To_JSON (Arr : Port_Array; Count : Natural) return String is
      Result : Unbounded_String;
      First  : Boolean := True;
   begin
      Append (Result, "[");
      for I in 1 .. Count loop
         if First then
            First := False;
         else
            Append (Result, ",");
         end if;
         Append (Result, "{""host"":");
         Append (Result, Ada.Strings.Fixed.Trim (Arr (I).Host'Image, Ada.Strings.Left));
         Append (Result, ",""container"":");
         Append (Result, Ada.Strings.Fixed.Trim (Arr (I).Container'Image, Ada.Strings.Left));
         Append (Result, "}");
      end loop;
      Append (Result, "]");
      return To_String (Result);
   end Port_Array_To_JSON;

   function Volume_Array_To_JSON (Arr : Volume_Array; Count : Natural) return String is
      Result : Unbounded_String;
      First  : Boolean := True;
   begin
      Append (Result, "[");
      for I in 1 .. Count loop
         if First then
            First := False;
         else
            Append (Result, ",");
         end if;
         Append (Result, "{""host"":""");
         Append (Result, Escape_JSON (To_String (Arr (I).Host)));
         Append (Result, """,""container"":""");
         Append (Result, Escape_JSON (To_String (Arr (I).Container)));
         Append (Result, """}");
      end loop;
      Append (Result, "]");
      return To_String (Result);
   end Volume_Array_To_JSON;

   -------------------------
   -- JSON deserialization
   -------------------------

   -- Simple JSON value parser. Each function parses the first occurrence
   -- of a named key from a JSON object and returns the value as a string.
   -- Format: {"key1":"val1","key2":"val2"} or {"host":123,"container":456}

   function Find_String_Value (S : String; Key : String) return String is
      Key_Pos : Natural;
      Colon   : Natural;
      Quote1  : Natural;
      Quote2  : Natural;
   begin
      Key_Pos := Ada.Strings.Fixed.Index (S, """" & Key & """:");
      if Key_Pos = 0 then
         return "";
      end if;
      Colon := Key_Pos + Key'Length + 3;
      if Colon > S'Last then
         return "";
      end if;
      Quote1 := Colon;
      while Quote1 <= S'Last and then S (Quote1) /= '"' loop
         Quote1 := Quote1 + 1;
      end loop;
      if Quote1 >= S'Last then
         return "";
      end if;
      Quote2 := Quote1 + 1;
      while Quote2 <= S'Last and then S (Quote2) /= '"' loop
         if S (Quote2) = '\' and then Quote2 < S'Last then
            Quote2 := Quote2 + 2;
         else
            Quote2 := Quote2 + 1;
         end if;
      end loop;
      if Quote2 > S'Last then
         return "";
      end if;
      return S (Quote1 + 1 .. Quote2 - 1);
   end Find_String_Value;

   function Find_Int_Value (S : String; Key : String) return Integer is
      Key_Pos : Natural;
      Colon   : Natural;
      Start_N : Natural;
      End_N   : Natural;
   begin
      Key_Pos := Ada.Strings.Fixed.Index (S, """" & Key & """:");
      if Key_Pos = 0 then
         return 0;
      end if;
      Colon := Key_Pos + Key'Length + 3;
      Start_N := Colon;
      while Start_N <= S'Last and then S (Start_N) in ' ' | ASCII.HT loop
         Start_N := Start_N + 1;
      end loop;
      End_N := Start_N;
      while End_N <= S'Last and then S (End_N) in '0' .. '9' loop
         End_N := End_N + 1;
      end loop;
      if End_N = Start_N then
         return 0;
      end if;
      return Integer'Value (S (Start_N .. End_N - 1));
   end Find_Int_Value;

   -- Parse a JSON array of objects and populate the Ada arrays.
   -- The array format is: [{...},{...},...]
   -- Count is set to the number of objects found.

   procedure Parse_Env_Array (JSON_Str : String; Arr : in out Env_Array; Count : out Natural) is
      Pos : Natural := JSON_Str'First;
   begin
      Count := 0;
      while Pos <= JSON_Str'Last and then JSON_Str (Pos) /= '{' loop
         Pos := Pos + 1;
      end loop;

      while Pos <= JSON_Str'Last and then Count < MAX_ENV_ENTRIES loop
         declare
            Obj_Start : constant Natural := Pos;
            Obj_End   : Natural := Obj_Start;
            Depth     : Natural := 0;
         begin
            while Obj_End <= JSON_Str'Last loop
               if JSON_Str (Obj_End) = '{' then
                  Depth := Depth + 1;
               elsif JSON_Str (Obj_End) = '}' then
                  Depth := Depth - 1;
                  if Depth = 0 then
                     exit;
                  end if;
               end if;
               Obj_End := Obj_End + 1;
            end loop;

            if Obj_End > JSON_Str'Last then
               exit;
            end if;

            declare
               Obj : constant String := JSON_Str (Obj_Start .. Obj_End);
            begin
               Count := Count + 1;
               Arr (Count).Key := To_Unbounded_String (Find_String_Value (Obj, "key"));
               Arr (Count).Value := To_Unbounded_String (Find_String_Value (Obj, "value"));
            end;

            Pos := Obj_End + 1;
            while Pos <= JSON_Str'Last and then JSON_Str (Pos) /= '{' loop
               Pos := Pos + 1;
            end loop;
         end;
      end loop;
   end Parse_Env_Array;

   procedure Parse_Port_Array (JSON_Str : String; Arr : in out Port_Array; Count : out Natural) is
      Pos : Natural := JSON_Str'First;
   begin
      Count := 0;
      while Pos <= JSON_Str'Last and then JSON_Str (Pos) /= '{' loop
         Pos := Pos + 1;
      end loop;

      while Pos <= JSON_Str'Last and then Count < MAX_PORTS_ENTRIES loop
         declare
            Obj_Start : constant Natural := Pos;
            Obj_End   : Natural := Obj_Start;
            Depth     : Natural := 0;
         begin
            while Obj_End <= JSON_Str'Last loop
               if JSON_Str (Obj_End) = '{' then
                  Depth := Depth + 1;
               elsif JSON_Str (Obj_End) = '}' then
                  Depth := Depth - 1;
                  if Depth = 0 then
                     exit;
                  end if;
               end if;
               Obj_End := Obj_End + 1;
            end loop;

            if Obj_End > JSON_Str'Last then
               exit;
            end if;

            declare
               Obj : constant String := JSON_Str (Obj_Start .. Obj_End);
            begin
               Count := Count + 1;
               Arr (Count) := (Host => Find_Int_Value (Obj, "host"), Container => Find_Int_Value (Obj, "container"));
            end;

            Pos := Obj_End + 1;
            while Pos <= JSON_Str'Last and then JSON_Str (Pos) /= '{' loop
               Pos := Pos + 1;
            end loop;
         end;
      end loop;
   end Parse_Port_Array;

   procedure Parse_Volume_Array (JSON_Str : String; Arr : in out Volume_Array; Count : out Natural) is
      Pos : Natural := JSON_Str'First;
   begin
      Count := 0;
      while Pos <= JSON_Str'Last and then JSON_Str (Pos) /= '{' loop
         Pos := Pos + 1;
      end loop;

      while Pos <= JSON_Str'Last and then Count < MAX_VOLUMES_ENTRIES loop
         declare
            Obj_Start : constant Natural := Pos;
            Obj_End   : Natural := Obj_Start;
            Depth     : Natural := 0;
         begin
            while Obj_End <= JSON_Str'Last loop
               if JSON_Str (Obj_End) = '{' then
                  Depth := Depth + 1;
               elsif JSON_Str (Obj_End) = '}' then
                  Depth := Depth - 1;
                  if Depth = 0 then
                     exit;
                  end if;
               end if;
               Obj_End := Obj_End + 1;
            end loop;

            if Obj_End > JSON_Str'Last then
               exit;
            end if;

            declare
               Obj : constant String := JSON_Str (Obj_Start .. Obj_End);
            begin
               Count := Count + 1;
               Arr (Count) :=
                 (Host      => To_Unbounded_String (Find_String_Value (Obj, "host")),
                  Container => To_Unbounded_String (Find_String_Value (Obj, "container")));
            end;

            Pos := Obj_End + 1;
            while Pos <= JSON_Str'Last and then JSON_Str (Pos) /= '{' loop
               Pos := Pos + 1;
            end loop;
         end;
      end loop;
   end Parse_Volume_Array;

end Podmander.Controller.Service.Json_Utils;
