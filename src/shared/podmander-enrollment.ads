--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Agent enrollment: join token generation, parsing, and secret validation.
--
--  A join token serialises the controller's CURVE public key and a one-shot
--  enrollment secret into a single human-transferable string. The controller
--  generates one with Generate_Join_Token and the agent recovers both halves
--  with Parse_Join_Token at startup.

with Ada.Strings.Unbounded;

package Podmander.Enrollment is

   use Ada.Strings.Unbounded;

   Token_Prefix      : constant String := "PTKN-";
   Public_Key_Length : constant Positive := 40;
   Secret_Length     : constant Positive := 32;
   Separator         : constant Character := '-';

   -- Raised by Parse_Join_Token when the input does not match the expected
   -- shape. The agent treats this as a fatal configuration error.
   Parse_Error : exception;

   type Parsed_Token is record
      Public_Key : Unbounded_String;
      Secret     : Unbounded_String;
   end record;

   type Enrollment_Config is record
      Secret : Unbounded_String;
   end record;

   procedure Set_Secret (Config : in out Enrollment_Config; Value : String);

   function Get_Secret (Config : Enrollment_Config) return String;

   function Has_Secret (Config : Enrollment_Config) return Boolean;

   procedure Ensure_Secret (Config : in out Enrollment_Config);
   --  Mints a random secret into Config when none is present; no-op otherwise.
   --  A restart never rotates a live secret.

   function Secret_Matches
     (Config : Enrollment_Config; Value : String) return Boolean;

   procedure Generate_Join_Token
     (Public_Key : String;
      Config     : in out Enrollment_Config;
      Token      : out Unbounded_String);

   function Parse_Join_Token (Token : String) return Parsed_Token;

end Podmander.Enrollment;
