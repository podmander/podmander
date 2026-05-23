--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Podmander.Config;
with Podmander.Controller;
with Podmander.Controller.Service.Json_Utils;
with Podmander.Database.Time_Utils;

package body Podmander.Controller.Service.Repository is

   use Ada.Strings.Unbounded;
   use Podmander.Config;
   use Podmander.Database.Time_Utils;
   use Podmander.Controller.Service.Json_Utils;

   --------------
   --  Query row
   --------------

   function Row_To_Service_Version
     (DB : in out DB_Handle; QH : in out Query_Handle)
      return Podmander.Controller.Service_Version
   is
      Result : Podmander.Controller.Service_Version;
   begin
      Result.Service_Name := To_Unbounded_String (Column_Text (QH, 0));
      Result.Version := Positive'Value (Column_Text (QH, 1));
      Result.Image := To_Unbounded_String (Column_Text (QH, 2));
      Parse_Env_Array (Column_Text (QH, 3), Result.Env, Result.Env_Count);
      Parse_Port_Array (Column_Text (QH, 4), Result.Ports, Result.Ports_Count);
      Parse_Volume_Array
        (Column_Text (QH, 5), Result.Volumes, Result.Volumes_Count);
      Result.Description := To_Unbounded_String (Column_Text (QH, 6));
      Result.Wanted_By := To_Unbounded_String (Column_Text (QH, 7));
      Result.Created_At := ISO8601_To_Time (Column_Text (QH, 8));
      return Result;
   exception
      when Constraint_Error =>
         raise Database_Error
           with
             Format_Error
               ((Kind    => Unknown,
                 Message =>
                   To_Unbounded_String ("Invalid version number in database"),
                 Code    => 0));
   end Row_To_Service_Version;

   --------------------
   --  Create_Version --
   --------------------

   procedure Create_Version
     (DB : in out DB_Handle; Version : Podmander.Controller.Service_Version)
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "INSERT INTO service_versions "
           & "(service_name, version, image, env, ports, volumes, "
           & "description, wanted_by, created_at) "
           & "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
   begin
      Bind_Text (QH, 1, To_String (Version.Service_Name));
      Bind_Text
        (QH,
         2,
         Ada.Strings.Fixed.Trim (Version.Version'Image, Ada.Strings.Left));
      Bind_Text (QH, 3, To_String (Version.Image));
      Bind_Text (QH, 4, Env_Array_To_JSON (Version.Env, Version.Env_Count));
      Bind_Text
        (QH, 5, Port_Array_To_JSON (Version.Ports, Version.Ports_Count));
      Bind_Text
        (QH, 6, Volume_Array_To_JSON (Version.Volumes, Version.Volumes_Count));
      Bind_Text (QH, 7, To_String (Version.Description));
      Bind_Text (QH, 8, To_String (Version.Wanted_By));
      Bind_Text (QH, 9, Time_To_ISO8601 (Version.Created_At));
      while Step (QH) loop
         null;
      end loop;
   end Create_Version;

   -----------------
   --  Get_Version --
   -----------------

   function Get_Version
     (DB : in out DB_Handle; Service_Name : String; Version : Positive)
      return Podmander.Controller.Service_Version
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "SELECT service_name, version, image, env, ports, volumes, "
           & "description, wanted_by, created_at "
           & "FROM service_versions "
           & "WHERE service_name = ? AND version = ?");
   begin
      Bind_Text (QH, 1, Service_Name);
      Bind_Text
        (QH, 2, Ada.Strings.Fixed.Trim (Version'Image, Ada.Strings.Left));
      if Step (QH) then
         return Row_To_Service_Version (DB, QH);
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Not_Found,
                 Message =>
                   To_Unbounded_String
                     ("Service version not found: "
                      & Service_Name
                      & " v"
                      & Ada.Strings.Fixed.Trim
                          (Version'Image, Ada.Strings.Left)),
                 Code    => 0));
      end if;
   end Get_Version;

   ------------------------
   --  Get_Latest_Version --
   ------------------------

   function Get_Latest_Version
     (DB : in out DB_Handle; Service_Name : String)
      return Podmander.Controller.Service_Version
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "SELECT service_name, version, image, env, ports, volumes, "
           & "description, wanted_by, created_at "
           & "FROM service_versions "
           & "WHERE service_name = ? "
           & "ORDER BY version DESC LIMIT 1");
   begin
      Bind_Text (QH, 1, Service_Name);
      if Step (QH) then
         return Row_To_Service_Version (DB, QH);
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Not_Found,
                 Message =>
                   To_Unbounded_String
                     ("No versions found for service: " & Service_Name),
                 Code    => 0));
      end if;
   end Get_Latest_Version;

end Podmander.Controller.Service.Repository;
