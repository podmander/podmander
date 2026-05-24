--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Podmander.Controller.Service.Json_Utils;
with Podmander.Database.Time_Utils;

package body Podmander.Controller.Service.Repository is

   use Ada.Strings.Unbounded;
   use Podmander.Database.Time_Utils;
   use Podmander.Controller.Service.Json_Utils;

   --------------
   -- Query row
   --------------

   function Row_To_Service_Version
     (DB : in out DB_Handle; QH : in out Query_Handle)
      return Podmander.Controller.Service_Version
   is
      pragma Unreferenced (DB);
      Result : Podmander.Controller.Service_Version;
   begin
      Result.Id := Column_Int (QH, 0);
      Result.Service_Id := Podmander.Controller.Service_Id_Type (Column_Int (QH, 1));
      Result.Version := Podmander.Controller.Service_Version_No'Value (Column_Text (QH, 2));
      Result.Image := To_Unbounded_String (Column_Text (QH, 3));
      Parse_Env_Array (Column_Text (QH, 4), Result.Env, Result.Env_Count);
      Parse_Port_Array (Column_Text (QH, 5), Result.Ports, Result.Ports_Count);
      Parse_Volume_Array
        (Column_Text (QH, 6), Result.Volumes, Result.Volumes_Count);
      Result.Description := To_Unbounded_String (Column_Text (QH, 7));
      Result.Wanted_By := To_Unbounded_String (Column_Text (QH, 8));
      Result.Created_At := ISO8601_To_Time (Column_Text (QH, 9));
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

   ------------
   -- Create --
   ------------

   function Create (DB : in out DB_Handle; Name : String) return Service is
      QH  : Query_Handle :=
        Prepare (DB, "INSERT OR IGNORE INTO services (name) VALUES (?)");
      SEL : Query_Handle :=
        Prepare (DB, "SELECT id, name FROM services WHERE name = ?");
   begin
      Bind_Text (QH, 1, Name);
      while Step (QH) loop
         null;
      end loop;

      Bind_Text (SEL, 1, Name);
      if Step (SEL) then
return
            (Id   => Podmander.Controller.Service_Id_Type (Column_Int (SEL, 0)),
             Name => To_Unbounded_String (Column_Text (SEL, 1)));
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Unknown,
                 Message =>
                   To_Unbounded_String
                     ("Failed to retrieve service after insert: " & Name),
                 Code    => 0));
      end if;
   end Create;

   -----------------
   -- Get_By_Name --
   -----------------

   function Get_By_Name (DB : in out DB_Handle; Name : String) return Service
   is
      QH : Query_Handle :=
        Prepare (DB, "SELECT id, name FROM services WHERE name = ?");
   begin
      Bind_Text (QH, 1, Name);
      if Step (QH) then
return
            (Id   => Podmander.Controller.Service_Id_Type (Column_Int (QH, 0)),
             Name => To_Unbounded_String (Column_Text (QH, 1)));
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Not_Found,
                  Message => To_Unbounded_String ("Service not found: " & Name),
                  Code    => 0));
      end if;
   end Get_By_Name;

   ---------------
   -- Get_By_Id --
   ---------------

   function Get_By_Id
      (DB : in out DB_Handle; Id : Podmander.Controller.Service_Id_Type) return Service
   is
      QH : Query_Handle :=
        Prepare (DB, "SELECT id, name FROM services WHERE id = ?");
   begin
      Bind_Text (QH, 1, Ada.Strings.Fixed.Trim (Id'Image, Ada.Strings.Left));
      if Step (QH) then
return
            (Id   => Podmander.Controller.Service_Id_Type (Column_Int (QH, 0)),
             Name => To_Unbounded_String (Column_Text (QH, 1)));
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Not_Found,
                  Message =>
                    To_Unbounded_String
                      ("Service not found by id: "
                       & Ada.Strings.Fixed.Trim (Id'Image, Ada.Strings.Left)),
                  Code    => 0));
      end if;
   end Get_By_Id;

   --------------------
   -- Create_Version --
   --------------------

   procedure Create_Version
     (DB : in out DB_Handle; Version : Podmander.Controller.Service_Version)
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "INSERT INTO service_versions "
           & "(service_id, version, image, env, ports, volumes, "
           & "description, wanted_by, created_at) "
           & "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
   begin
      Bind_Text
        (QH,
         1,
         Ada.Strings.Fixed.Trim (Version.Service_Id'Image, Ada.Strings.Left));
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
   -- Get_Version --
   -----------------

function Get_Version
      (DB             : in out DB_Handle;
       Service_Id     : Podmander.Controller.Service_Id_Type;
       Version        : Podmander.Controller.Service_Version_No)
       return Podmander.Controller.Service_Version
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "SELECT id, service_id, version, image, env, ports, volumes, "
           & "description, wanted_by, created_at "
           & "FROM service_versions "
           & "WHERE service_id = ? AND version = ?");
   begin
      Bind_Text
        (QH, 1, Ada.Strings.Fixed.Trim (Service_Id'Image, Ada.Strings.Left));
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
                     ("Service version not found: service_id "
                      & Ada.Strings.Fixed.Trim
                          (Service_Id'Image, Ada.Strings.Left)
                      & " v"
                      & Ada.Strings.Fixed.Trim
                          (Version'Image, Ada.Strings.Left)),
                 Code    => 0));
      end if;
   end Get_Version;

   ------------------------
   -- Get_Latest_Version --
   ------------------------

function Get_Latest_Version
      (DB : in out DB_Handle; Service_Id : Podmander.Controller.Service_Id_Type)
       return Podmander.Controller.Service_Version
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "SELECT id, service_id, version, image, env, ports, volumes, "
           & "description, wanted_by, created_at "
           & "FROM service_versions "
           & "WHERE service_id = ? "
           & "ORDER BY version DESC LIMIT 1");
   begin
      Bind_Text
        (QH, 1, Ada.Strings.Fixed.Trim (Service_Id'Image, Ada.Strings.Left));
      if Step (QH) then
         return Row_To_Service_Version (DB, QH);
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Not_Found,
                 Message =>
                   To_Unbounded_String
                     ("No versions found for service_id: "
                      & Ada.Strings.Fixed.Trim
                          (Service_Id'Image, Ada.Strings.Left)),
                 Code    => 0));
      end if;
   end Get_Latest_Version;

end Podmander.Controller.Service.Repository;
