--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Numerics.Discrete_Random;

package body Podmander.Enrollment is

   Hex_Chars : constant String := "0123456789abcdef";

   subtype Hex_Range is Natural range 0 .. 15;
   package Hex_Rand is new Ada.Numerics.Discrete_Random (Hex_Range);

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

   procedure Set_Secret
     (Config : in out Enrollment_Config;
      Value  : String) is
   begin
      Config.Secret := To_Unbounded_String (Value);
   end Set_Secret;

   function Get_Secret (Config : Enrollment_Config) return String is
   begin
      return To_String (Config.Secret);
   end Get_Secret;

   function Secret_Matches
     (Config : Enrollment_Config;
      Value  : String) return Boolean is
   begin
      return To_String (Config.Secret) = Value;
   end Secret_Matches;

   procedure Generate_Join_Token
     (Public_Key : String;
      Config     : in out Enrollment_Config;
      Token      : out Unbounded_String) is
      Secret : constant String := Random_Hex (32);
   begin
      Config.Secret := To_Unbounded_String (Secret);
      Token := To_Unbounded_String
        (Token_Prefix & Public_Key & "-" & Secret);
   end Generate_Join_Token;

end Podmander.Enrollment;
