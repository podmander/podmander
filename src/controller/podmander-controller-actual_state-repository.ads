--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Repository for Actual_State persistence.
--  Operations: Upsert (on Deploy_Result), Get_All, Get_For_Service, Remove.

with Podmander.Controller;
with Podmander.Database;

package Podmander.Controller.Actual_State.Repository is

   use Podmander.Database;

   procedure Upsert
     (DB : in out DB_Handle; Rec : Podmander.Controller.Actual_State_Entry);
   --  Insert or update an actual_state entry. Called on Deploy_Result
   --  to record what version of a service is deployed on which node.

   function Get_All
     (DB : in out DB_Handle)
      return Podmander.Controller.Actual_State_Vectors.Vector;
   --  Return all actual_state entries. Used by the supervisor loop to
   --  compare desired vs actual state across all services and nodes.

   function Get_For_Service
     (DB : in out DB_Handle; Service_Name : String)
      return Podmander.Controller.Actual_State_Vectors.Vector;
   --  Return all actual_state entries for a specific service.
   --  Returns an empty vector if the service has no entries.

   procedure Remove
     (DB : in out DB_Handle; Service_Name : String; Node_Id : String);
   --  Remove an actual_state entry. Used when a service is undeployed
   --  from a node. No-op if the entry does not exist.

end Podmander.Controller.Actual_State.Repository;
