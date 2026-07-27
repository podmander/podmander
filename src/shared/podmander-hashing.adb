--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with SHA256;

package body Podmander.Hashing is

   package SE renames System.Storage_Elements;
   use type SE.Storage_Offset;
   Hex_Characters : constant String := "0123456789abcdef";

   function SHA256_Hex
     (Data : SE.Storage_Array) return String is
      Input  : SE.Storage_Array (0 .. Data'Length - 1);
      Ctx    : SHA256.Context;
      Digest : SHA256.Digest;
      Result : String (1 .. 64);
   begin
      for I in Data'Range loop
         Input (I - Data'First) := Data (I);
      end loop;

      SHA256.Initialize (Ctx);
      SHA256.Update (Ctx, Input);
      SHA256.Finalize (Ctx, Digest);

      for I in Digest'Range loop
         declare
            Value : constant Natural := Natural (Digest (I));
            Pos   : constant Natural := Natural (I - Digest'First) * 2 + 1;
         begin
            Result (Pos)     := Hex_Characters (Value / 16 + 1);
            Result (Pos + 1) := Hex_Characters (Value mod 16 + 1);
         end;
      end loop;

      return Result;
   end SHA256_Hex;

end Podmander.Hashing;
