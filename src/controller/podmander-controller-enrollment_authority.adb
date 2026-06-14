--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Podmander.Logging;

package body Podmander.Controller.Enrollment_Authority is

   procedure Bootstrap_Certificate
     (Cert : in out CZMQ.Certificates.Certificate; Cert_Path : String) is
   begin
      if Ada.Directories.Exists (Cert_Path) then
         Cert.Load (Cert_Path);
         Podmander.Logging.Info
           ("controller", "Loaded CURVE certificate from " & Cert_Path);
      else
         Cert.Generate;
         Cert.Save (Cert_Path);
         Podmander.Logging.Info
           ("controller",
            "Generated and saved CURVE certificate to " & Cert_Path);
      end if;
   end Bootstrap_Certificate;

   procedure Bootstrap_Secret
     (DB     : in out Podmander.Database.DB_Handle;
      Config : in out Podmander.Enrollment.Enrollment_Config)
   is
      use Ada.Strings.Unbounded;
      use Podmander.Database;
   begin
      Config.Secret :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (Get_Setting (DB, "registration_secret"));
      Podmander.Logging.Info
        ("controller", "Loaded registration secret from DB");
   exception
      when E : Database_Error =>
         if Parse_Error (E).Kind = Not_Found then
            Podmander.Enrollment.Ensure_Secret (Config);
            Set_Setting
              (DB,
               "registration_secret",
               Ada.Strings.Unbounded.To_String (Config.Secret));
            Podmander.Logging.Info
              ("controller", "Generated and persisted registration secret");
         else
            raise;
         end if;
   end Bootstrap_Secret;

   function Get_Public_Key (Cert : CZMQ.Certificates.Certificate) return String
   is
   begin
      if Cert.Is_Valid then
         return Cert.Public_Key;
      else
         return "";
      end if;
   end Get_Public_Key;

   procedure Generate_Join_Token
     (Cert   : CZMQ.Certificates.Certificate;
      Config : Podmander.Enrollment.Enrollment_Config;
      Token  : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Podmander.Enrollment.Generate_Join_Token
        (Public_Key => Get_Public_Key (Cert),
         Config     => Config,
         Token      => Token);
   end Generate_Join_Token;

   function Authorize
     (Config : Podmander.Enrollment.Enrollment_Config; Secret : String)
      return Boolean is
   begin
      return Podmander.Enrollment.Secret_Matches (Config, Secret);
   end Authorize;

end Podmander.Controller.Enrollment_Authority;
