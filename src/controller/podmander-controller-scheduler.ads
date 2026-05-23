--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  The Scheduler creates or updates service_catalog entries to schedule
--  a service for deployment. For MVP, it always assigns the single
--  connected agent (or NULL if none connected).

with Podmander.Database;

package Podmander.Controller.Scheduler is

   use Podmander.Database;

   type Schedule_Error is (None, Database_Error);

   type Schedule_Result is record
      Ok            : Boolean := False;
      Catalog_Entry : Podmander.Controller.Service_Catalog_Entry;
      Error         : Schedule_Error := None;
   end record;

   function Schedule
     (DB : in out DB_Handle; Service_Id : Integer; Target_Version : Positive; Node_Id : String) return Schedule_Result;
   -- Create or update a catalog entry for the given service.
   -- If an entry already exists for this service, update target_version
   -- and clear failed. If no entry exists, create one with
   -- current_version = 0 and the given target_version.
   -- Node_Id is the connected agent's node name, or empty string
   -- if no agent is connected (will be stored as NULL).

end Podmander.Controller.Scheduler;
