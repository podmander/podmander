--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Numerics.Discrete_Random;

package body Podmander.Enrollment is

   Hex_Chars : constant String := "0123456789abcdef";

   subtype Hex_Range is Natural range 0 .. 15;
   package Hex_Rand is new Ada.Numerics.Discrete_Random (Hex_Range);

   --  Total length of a well-formed join token.
   Token_Length : constant Positive :=
     Token_Prefix'Length + Public_Key_Length + 1 + Secret_Length;

   function Random_Hex (Length : Positive) return String is
      Gen : Hex_Rand.Generator;
   begin
      Hex_Rand.Reset (Gen);
      declare
         Result : String (1 .. Length);
      begin
         for I in Result'Range loop
            Result (I) := Hex_Chars (Hex_Rand.Random (Gen) + 1);
         end loop;
         return Result;
      end;
   end Random_Hex;

   procedure Set_Secret (Config : in out Enrollment_Config; Value : String) is
   begin
      Config.Secret := To_Unbounded_String (Value);
   end Set_Secret;

   function Get_Secret (Config : Enrollment_Config) return String is
   begin
      return To_String (Config.Secret);
   end Get_Secret;

   function Secret_Matches
     (Config : Enrollment_Config; Value : String) return Boolean is
   begin
      return To_String (Config.Secret) = Value;
   end Secret_Matches;

   procedure Generate_Join_Token
     (Public_Key : String;
      Config     : in out Enrollment_Config;
      Token      : out Unbounded_String) is
   begin
      --  Generate a new secret only if one isn't already set
      if Config.Secret = Null_Unbounded_String then
         Config.Secret := To_Unbounded_String (Random_Hex (Secret_Length));
      end if;
      Token :=
        To_Unbounded_String
          (Token_Prefix & Public_Key & Separator & To_String (Config.Secret));
   end Generate_Join_Token;

   function Parse_Join_Token (Token : String) return Parsed_Token is
      Key_Start    : constant Positive := Token'First + Token_Prefix'Length;
      Key_End      : constant Positive := Key_Start + Public_Key_Length - 1;
      Separator_At : constant Positive := Key_End + 1;
      Secret_Start : constant Positive := Separator_At + 1;
      Secret_End   : constant Positive := Secret_Start + Secret_Length - 1;
   begin
      if Token'Length /= Token_Length then
         raise Parse_Error with "Token has wrong length";
      end if;

      if Token (Token'First .. Token'First + Token_Prefix'Length - 1)
        /= Token_Prefix
      then
         raise Parse_Error with "Token has wrong prefix";
      end if;

      if Token (Separator_At) /= Separator then
         raise Parse_Error with "Token separator missing";
      end if;

      return
        (Public_Key => To_Unbounded_String (Token (Key_Start .. Key_End)),
         Secret     =>
           To_Unbounded_String (Token (Secret_Start .. Secret_End)));
   end Parse_Join_Token;

end Podmander.Enrollment;
