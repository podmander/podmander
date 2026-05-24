--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Repository for Service_Catalog_Entry persistence.
--  The catalog is the single source of truth for deployment intent and status.

with Podmander.Database;

package Podmander.Controller.Service_Catalog.Repository is

   use Podmander.Database;

   function Create_Entry
     (DB             : in out DB_Handle;
      Service_Id     : Integer;
      Node_Id        : String;
      Target_Version : Positive)
      return Podmander.Controller.Service_Catalog_Entry;
   -- Insert a new catalog entry. Node_Id may be empty (not yet scheduled).
   -- Returns the created entry with its auto-generated id.

   function Get_By_Id
     (DB : in out DB_Handle; Id : Integer)
      return Podmander.Controller.Service_Catalog_Entry;
   -- Return a catalog entry by id.
   -- Raises Database_Error with Not_Found if no matching entry exists.

   function Get_By_Service_Id
     (DB : in out DB_Handle; Service_Id : Integer)
      return Podmander.Controller.Service_Catalog_Entry;
   -- Return the catalog entry for the given service_id.
   -- Raises Database_Error with Not_Found if no entry exists.
   -- If multiple entries exist (different nodes), returns the first one.

   function Get_Unscheduled
     (DB : in out DB_Handle)
      return Podmander.Controller.Catalog_Entry_Vectors.Vector;
   -- Return all catalog entries where node_id IS NULL.

   function Get_Drift
      (DB : in out DB_Handle)
       return Podmander.Controller.Catalog_Entry_Vectors.Vector;
   -- Return all catalog entries where state = Pending.

   function Update_On_Success
      (DB : in out DB_Handle; Id : Integer; Current_Version : Natural)
       return Boolean;
   -- Set current_version = Current_Version, state = Deployed, update updated_at.
   -- Returns True if a row was updated, False otherwise.

   function Update_On_Failure
      (DB : in out DB_Handle; Id : Integer) return Boolean;
   -- Set state = Failed, update updated_at.
   -- Returns True if a row was updated, False otherwise.

   function Assign_Node
     (DB : in out DB_Handle; Id : Integer; Node_Id : String) return Boolean;
   -- Set node_id = Node_Id, update updated_at.
   -- Returns True if a row was updated, False otherwise.

   function Set_Target
      (DB : in out DB_Handle; Id : Integer; Target_Version : Positive)
       return Boolean;
   -- Set target_version = Target_Version, state = Pending,
   -- update updated_at.  Returns True if a row was updated, False otherwise.

   function Set_State
     (DB : in out DB_Handle; Id : Integer; State : Catalog_Entry_State)
      return Boolean;
   --  Set state = State, update updated_at.
   --  Returns True if a row was updated, False otherwise.

   procedure Reset_In_Progress_For_Node
     (DB : in out DB_Handle; Node_Id : String);
   --  Reset all In_Progress catalog entries for the given node
   --  back to Pending. Called when an agent reconnects to ensure
   --  any lost deploy commands are retried.

   procedure Reset_In_Progress (DB : in out DB_Handle);
   --  Reset all In_Progress entries to Pending.
   --  Called on controller startup to handle stale in-progress entries
   --  from a previous controller crash.

end Podmander.Controller.Service_Catalog.Repository;
