--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  The Scheduler creates or updates service_catalog entries to schedule
--  a service for deployment. Agent selection is delegated to the injected
--  Scheduling Strategy; the Scheduler owns only persistence.

with Podmander.Controller.Strategies;
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
     (DB             : in out DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Target_Version : Podmander.Controller.Service_Version_Type;
      Strategy       : Podmander.Controller.Strategies.Strategy_Type'Class)
      return Schedule_Result;
   --  Create or update a catalog entry for the given service, using the
   --  provided Scheduling Strategy to select the target agent.
   --  If an entry already exists, updates target_version and state = Pending.
   --  If no entry exists, creates one with current_version = 0.
   --  Agent_Id = 0 when Strategy finds no eligible agent (entry unscheduled).

   function Schedule
     (DB             : in out DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Schedule_Result;
   --  Convenience overload using the First_Available scheduling strategy.

end Podmander.Controller.Scheduler;
