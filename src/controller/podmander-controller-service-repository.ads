--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Repository for Service_Version persistence.
--  Domain-driven operations: Create_Version, Get_Version, Get_Latest_Version.
--  Complex ASD fields (env, ports, volumes) are JSON-serialized for storage.

with Podmander.Controller;
with Podmander.Database;

package Podmander.Controller.Service.Repository is

   use Podmander.Database;

   procedure Create_Version
     (DB      : in out DB_Handle;
      Version : Podmander.Controller.Service_Version);
   --  Persist a new Service_Version. Raises Database_Error with
   --  Constraint_Violation on UNIQUE (service_name, version) violation.

   function Get_Version
     (DB           : in out DB_Handle;
      Service_Name : String;
      Version      : Positive)
      return Podmander.Controller.Service_Version;
   --  Return a specific Service_Version by (service_name, version).
   --  Raises Database_Error with Not_Found if no matching version exists.

   function Get_Latest_Version
     (DB           : in out DB_Handle;
      Service_Name : String)
      return Podmander.Controller.Service_Version;
   --  Return the highest version number for the given service.
   --  Raises Database_Error with Not_Found if no versions exist for service.

end Podmander.Controller.Service.Repository;
