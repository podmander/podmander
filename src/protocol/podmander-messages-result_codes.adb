--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Characters.Handling;

package body Podmander.Messages.Result_Codes is

   function Encode_Code (Code : Result_Code) return String
   is (Ada.Characters.Handling.To_Upper (Result_Code'Image (Code)));

   function Decode_Code (S : String) return Result_Code is
      Upper : constant String := Ada.Characters.Handling.To_Upper (S);
   begin
      return Result_Code'Value (Upper);
   exception
      when Constraint_Error =>
         raise Podmander.Messages.Decode_Error
           with "unknown result code: " & S;
   end Decode_Code;

end Podmander.Messages.Result_Codes;
