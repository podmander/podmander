--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  The Registrar creates the services row (if new) and service_versions row
--  from a parsed Service_Definition (ASD). It is the first stage of the
--  deploy pipeline: Parser -> Registrar -> Scheduler -> Supervisor.

with Podmander.Config;
with Podmander.Database;

package Podmander.Controller.Registrar is

   use Podmander.Database;

   type Register_Error is (None, Parse_Failed, Database_Error);

   type Register_Result is record
      Ok      : Boolean := False;
      Version : Podmander.Controller.Service_Version;
      Error   : Register_Error := None;
   end record;

   function Register
     (DB : in out DB_Handle; ASD : Podmander.Config.Service_Definition)
      return Register_Result;
   -- Register a service from its parsed ASD:
   -- 1. Create the services row (INSERT OR IGNORE, then SELECT)
   -- 2. Determine next version number (latest + 1, or 1 if none)
   -- 3. Create the service_versions row
   -- Returns a Register_Result with the created Service_Version on success,
   -- or an error code on failure.

end Podmander.Controller.Registrar;
