--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  The Scheduler creates or updates service_catalog entries to schedule
--  a service for deployment. It selects the target node by querying
--  available agents. For MVP, it assigns the first connected agent
--  (or leaves node_id NULL if none connected).

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
     (DB : in out DB_Handle; Service_Id : Integer; Target_Version : Positive)
      return Schedule_Result;
   --  Create or update a catalog entry for the given service.
   --  If an entry already exists for this service, update target_version
   --  and clear failed. If no entry exists, create one with
   --  current_version = 0 and the given target_version.
   --  The Scheduler selects the target node by querying registered
   --  agents: 0 agents → unscheduled (node_id NULL), otherwise
   --  assigns the first registered agent found.

end Podmander.Controller.Scheduler;