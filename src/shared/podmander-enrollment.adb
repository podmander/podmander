--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Interfaces.C;
with System;

package body Podmander.Enrollment is

   Hex_Chars : constant String := "0123456789abcdef";

   -- Total length of a well-formed join token.
   Token_Length : constant Positive :=
     Token_Prefix'Length + Public_Key_Length + 1 + Secret_Length;

   function getrandom
     (buf    : System.Address;
      buflen : Interfaces.C.size_t;
      flags  : Interfaces.C.unsigned) return Interfaces.C.long
   with Import => True, Convention => C, External_Name => "getrandom";

   function Get_Random_Bytes (Length : Positive) return Byte_Array is
      use type Interfaces.C.long;
      Buf   : Byte_Array (1 .. Length);
      Total : Natural := 0;
   begin
      while Total < Length loop
         declare
            Remaining : constant Interfaces.C.size_t :=
              Interfaces.C.size_t (Length - Total);
            Got       : constant Interfaces.C.long :=
              getrandom
                (buf    => Buf (Total + 1)'Address,
                 buflen => Remaining,
                 flags  => 0);
         begin
            if Got = -1 then
               raise CSPRNG_Error with "getrandom(2) failed";
            end if;
            Total := Total + Natural (Got);
         end;
      end loop;
      return Buf;
   end Get_Random_Bytes;

   function Bytes_To_Hex (Bytes : Byte_Array) return String is
      Result : String (1 .. Bytes'Length);
   begin
      for I in Bytes'Range loop
         Result (I - Bytes'First + 1) :=
           Hex_Chars (Natural (Bytes (I)) mod 16 + 1);
      end loop;
      return Result;
   end Bytes_To_Hex;

   function Random_Hex (Length : Positive) return String is
   begin
      return Bytes_To_Hex (Get_Random_Bytes (Length));
   end Random_Hex;

   procedure Set_Secret (Config : in out Enrollment_Config; Value : String) is
   begin
      Config.Secret := To_Unbounded_String (Value);
   end Set_Secret;

   function Get_Secret (Config : Enrollment_Config) return String is
   begin
      return To_String (Config.Secret);
   end Get_Secret;

   function Has_Secret (Config : Enrollment_Config) return Boolean is
   begin
      return Config.Secret /= Null_Unbounded_String;
   end Has_Secret;

   procedure Ensure_Secret (Config : in out Enrollment_Config) is
   begin
      if not Has_Secret (Config) then
         Config.Secret := To_Unbounded_String (Random_Hex (Secret_Length));
      end if;
   end Ensure_Secret;

   function Secret_Matches
     (Config : Enrollment_Config; Value : String) return Boolean is
   begin
      return To_String (Config.Secret) = Value;
   end Secret_Matches;

   procedure Generate_Join_Token
     (Public_Key : String;
      Config     : Enrollment_Config;
      Token      : out Unbounded_String) is
   begin
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
