--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Hashing;
with System.Storage_Elements;

package body Podmander.Hashing_Tests is

   use AUnit.Assertions;
   package SE renames System.Storage_Elements;
   use type SE.Storage_Offset;

   type Hashing_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Hashing_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander Hashing"));

   overriding
   procedure Register_Tests (T : in out Hashing_Test);

   procedure Test_Empty_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : constant SE.Storage_Array (1 .. 0) := [others => 0];
   begin
      Assert
        (Podmander.Hashing.SHA256_Hex (Data)
         = "e3b0c44298fc1c149afbf4c8996fb924"
           & "27ae41e4649b934ca495991b7852b855",
         "SHA-256 of empty input");
   end Test_Empty_Input;

   procedure Test_Ascii_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : constant SE.Storage_Array :=
        [SE.Storage_Element (Character'Pos ('a')),
         SE.Storage_Element (Character'Pos ('b')),
         SE.Storage_Element (Character'Pos ('c'))];
   begin
      Assert
        (Podmander.Hashing.SHA256_Hex (Data)
         = "ba7816bf8f01cfea414140de5dae2223"
           & "b00361a396177a9cb410ff61f20015ad",
         "SHA-256 of abc");
   end Test_Ascii_Input;

   procedure Test_LF_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : constant SE.Storage_Array :=
        [16#6C#,
         16#69#,
         16#6E#,
         16#65#,
         16#31#,
         16#0A#,
         16#6C#,
         16#69#,
         16#6E#,
         16#65#,
         16#32#,
         16#0A#];
   begin
      Assert
        (Podmander.Hashing.SHA256_Hex (Data)
         = "2751a3a2f303ad21752038085e2b8c5f"
           & "98ecff61a2e4ebbd43506a941725be80",
         "SHA-256 of LF-containing input");
   end Test_LF_Input;

   procedure Test_UTF8_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : constant SE.Storage_Array :=
        [16#63#, 16#61#, 16#66#, 16#C3#, 16#A9#];
   begin
      Assert
        (Podmander.Hashing.SHA256_Hex (Data)
         = "850f7dc43910ff890f8879c0ed26fe69"
           & "7c93a067ad93a7d50f466a7028a9bf4e",
         "SHA-256 of UTF-8 input");
   end Test_UTF8_Input;

   procedure Test_Binary_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : constant SE.Storage_Array (-2 .. 2) :=
        [0, 16#01#, 16#80#, 16#FE#, 16#FF#];
   begin
      Assert
        (Podmander.Hashing.SHA256_Hex (Data)
         = "084d539f7f923049487dce190308e8e4"
           & "0061b6fce86484c4e23dfa87ee63ef01",
         "SHA-256 of binary input");
   end Test_Binary_Input;

   overriding
   procedure Register_Tests (T : in out Hashing_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Empty_Input'Access, "Empty input");
      Register_Routine (T, Test_Ascii_Input'Access, "ASCII input");
      Register_Routine (T, Test_LF_Input'Access, "LF-containing input");
      Register_Routine (T, Test_UTF8_Input'Access, "UTF-8 input");
      Register_Routine (T, Test_Binary_Input'Access, "Binary input");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Hashing_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Hashing_Tests;
