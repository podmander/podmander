--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Database;
with Podmander.Types;

package Podmander.Controller.Agent.Repository is

   use Podmander.Database;

   procedure Register
     (DB : in out DB_Handle; Agent : Podmander.Types.Agent_Info);
   --  Persist a newly enrolled agent. Raises Database_Error with
   --  Constraint_Violation if an agent with the same name already exists.

   procedure Touch (DB : in out DB_Handle; Agent : Podmander.Types.Agent_Info);
   --  Update an agent's last_seen timestamp. Called on each heartbeat.
   --  Raises Database_Error with Not_Found if the agent does not exist.

   procedure Set_State
     (DB : in out DB_Handle; Agent : Podmander.Types.Agent_Info);
   --  Update an agent's connection state.
   --  Raises Database_Error with Not_Found if the agent does not exist.

   function Load_All (DB : in out DB_Handle) return Agent_Maps.Map;
   --  Return all persisted agents as an in-memory map.

   procedure Remove
     (DB : in out DB_Handle; Agent : Podmander.Types.Agent_Info);
   --  Remove an agent from the database. No-op if the agent does not exist.

end Podmander.Controller.Agent.Repository;
