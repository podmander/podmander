--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with CZMQ.Certificates;
with Podmander.Database;
with Podmander.Enrollment;

package Podmander.Controller.Enrollment_Authority is

   procedure Bootstrap_Certificate
     (Cert      : in out CZMQ.Certificates.Certificate;
      Cert_Path :        String);
   --  Load from Cert_Path if it exists; generate and save to Cert_Path if not.

   procedure Bootstrap_Secret
     (DB         : in out Podmander.Database.DB_Handle;
      Public_Key :        String;
      Config     : in out Podmander.Enrollment.Enrollment_Config);
   --  Load "registration_secret" from DB into Config. If absent, mint one via
   --  Podmander.Enrollment.Generate_Join_Token (Public_Key threaded through;
   --  the produced token is discarded) and persist it with Set_Setting.

   function Get_Public_Key
     (Cert : CZMQ.Certificates.Certificate) return String;
   --  Returns Cert.Public_Key when Cert.Is_Valid, otherwise "".

   procedure Generate_Join_Token
     (Cert   :        CZMQ.Certificates.Certificate;
      Config : in out Podmander.Enrollment.Enrollment_Config;
      Token  :    out Ada.Strings.Unbounded.Unbounded_String);
   --  Delegates to Podmander.Enrollment.Generate_Join_Token.

   function Authorize
     (Config : Podmander.Enrollment.Enrollment_Config;
      Secret : String) return Boolean;
   --  True when Secret matches Config's enrollment secret.

end Podmander.Controller.Enrollment_Authority;
