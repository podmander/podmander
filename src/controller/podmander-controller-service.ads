--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;

package Podmander.Controller.Service is

   type Service is record
      Id   : Podmander.Controller.Service_Id_Type;
      Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Podmander.Controller.Service;
