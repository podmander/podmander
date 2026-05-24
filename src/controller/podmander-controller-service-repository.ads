--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Repository for Service and Service_Version persistence.
--  Domain-driven operations: Create, Get_By_Name, Get_By_Id for Service.
--  Also Create_Version, Get_Version, Get_Latest_Version for Service_Version.
--  Complex ASD fields (env, ports, volumes) are JSON-serialized for storage.

with Podmander.Database;

package Podmander.Controller.Service.Repository is

   use Podmander.Database;

   function Create (DB : in out DB_Handle; Name : String) return Service;
   -- Create a new service or return existing one if name already exists.
   -- Uses INSERT OR IGNORE followed by SELECT to get the id.
   -- Returns a Service record with the id and name.

   function Get_By_Name (DB : in out DB_Handle; Name : String) return Service;
   -- Return a Service by name. Raises Database_Error with Not_Found
   -- if no matching service exists.

function Get_By_Id
      (DB : in out DB_Handle; Id : Podmander.Controller.Service_Id_Type)
       return Service;
   -- Return a Service by id. Raises Database_Error with Not_Found
   -- if no matching service exists.

   procedure Create_Version
      (DB : in out DB_Handle; Version : Podmander.Controller.Service_Version);
   -- Persist a new Service_Version. Raises Database_Error with
   -- Constraint_Violation on UNIQUE (service_id, version) violation.

   function Get_Version
      (DB             : in out DB_Handle;
       Service_Id     : Podmander.Controller.Service_Id_Type;
       Version        : Podmander.Controller.Service_Version_No)
       return Podmander.Controller.Service_Version;
   -- Return a specific Service_Version by (service_id, version).
   -- Raises Database_Error with Not_Found if no matching version exists.

   function Get_Latest_Version
      (DB : in out DB_Handle; Service_Id : Podmander.Controller.Service_Id_Type)
       return Podmander.Controller.Service_Version;
   -- Return the highest version number for the given service id.
   -- Raises Database_Error with Not_Found if no versions exist for service.

end Podmander.Controller.Service.Repository;
