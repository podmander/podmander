--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Service;
with Podmander.Controller.Service.Repository;

package body Podmander.Controller.Registrar is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;

function To_Service_Version
      (ASD : Service_Definition;
       Service_Id : Podmander.Controller.Service_Id_Type;
       Version    : Podmander.Controller.Service_Version_Type)
       return Podmander.Controller.Service_Version is
   begin
      return
        (Id            => 0,
         Service_Id    => Service_Id,
         Version       => Version,
         Image         => ASD.Image,
         Env           => ASD.Env,
         Env_Count     => ASD.Env_Count,
         Ports         => ASD.Ports,
         Ports_Count   => ASD.Ports_Count,
         Volumes       => ASD.Volumes,
         Volumes_Count => ASD.Volumes_Count,
         Description   => ASD.Description,
         Wanted_By     => ASD.WantedBy,
         Created_At    => Clock);
   end To_Service_Version;

   --------------
   -- Register --
   --------------

   function Register
     (DB : in out DB_Handle; ASD : Podmander.Config.Service_Definition)
      return Register_Result
   is
      Name        : constant String := To_String (ASD.Name);
      Svc         : Podmander.Controller.Service.Service;
      Version_Num : Podmander.Controller.Service_Version_Type := 1;
      SV          : Podmander.Controller.Service_Version;
   begin
      -- Step 1: Create or get existing service row
      Svc := Podmander.Controller.Service.Repository.Create (DB, Name);

      -- Step 2: Determine next version number
      begin
         declare
            Latest : constant Podmander.Controller.Service_Version :=
              Podmander.Controller.Service.Repository.Get_Latest_Version
                (DB, Svc.Id);
         begin
            Version_Num := Latest.Version + 1;
         end;
      exception
         when E : Podmander.Database.Database_Error =>
            declare
               Err : constant Error_Info := Parse_Error (E);
            begin
               if Err.Kind = Not_Found then
                  -- No existing version for this service; start at 1
                  null;
               else
                  return (Ok => False, Version => SV, Error => Database_Error);
               end if;
            end;
      end;

      -- Step 3: Build the Service_Version record
      SV := To_Service_Version (ASD, Svc.Id, Version_Num);

      -- Step 4: Persist the version
      begin
         Podmander.Controller.Service.Repository.Create_Version (DB, SV);
      exception
         when Podmander.Database.Database_Error =>
            return (Ok => False, Version => SV, Error => Database_Error);
      end;

      -- Step 5: Return success
      return (Ok => True, Version => SV, Error => None);
   end Register;

end Podmander.Controller.Registrar;
