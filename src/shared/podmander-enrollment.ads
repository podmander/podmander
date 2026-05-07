--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Agent enrollment: join token generation and secret validation.

with Ada.Strings.Unbounded;

package Podmander.Enrollment is

   use Ada.Strings.Unbounded;

   Token_Prefix : constant String := "PTKN-";

   type Enrollment_Config is record
      Secret : Unbounded_String;
   end record;

   procedure Set_Secret
     (Config : in out Enrollment_Config;
      Value  : String);

   function Get_Secret (Config : Enrollment_Config) return String;

   function Secret_Matches
     (Config : Enrollment_Config;
      Value  : String) return Boolean;

   procedure Generate_Join_Token
     (Public_Key : String;
      Config     : in out Enrollment_Config;
      Token      : out Unbounded_String);

end Podmander.Enrollment;
