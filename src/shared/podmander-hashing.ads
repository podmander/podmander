--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with System.Storage_Elements;

package Podmander.Hashing is

   function SHA256_Hex
     (Data : System.Storage_Elements.Storage_Array) return String;

end Podmander.Hashing;
