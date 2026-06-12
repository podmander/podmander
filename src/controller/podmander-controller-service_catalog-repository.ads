--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Repository for Service_Catalog_Entry persistence.
--  The catalog is the single source of truth for deployment intent and status.

with Podmander.Database;
with Podmander.Types;

package Podmander.Controller.Service_Catalog.Repository is

   use Podmander.Database;

   function Create_Entry
     (DB             : in out DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Node_Id        : Podmander.Types.Node_Id_Type := 0;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Podmander.Controller.Service_Catalog_Entry;
   -- Insert a new catalog entry. Node_Id 0 means unscheduled.
   -- Returns the created entry with its auto-generated id.

   function Get_By_Id
     (DB : in out DB_Handle; Id : Integer)
      return Podmander.Controller.Service_Catalog_Entry;
   -- Return a catalog entry by id.
   -- Raises Database_Error with Not_Found if no matching entry exists.

   function Get_By_Service_Id
     (DB : in out DB_Handle; Service_Id : Podmander.Controller.Service_Id_Type)
      return Podmander.Controller.Service_Catalog_Entry;
   -- Return the catalog entry for the given service_id.
   -- Raises Database_Error with Not_Found if no entry exists.
   -- If multiple entries exist (different nodes), returns the first one.

   function Get_Unscheduled
     (DB : in out DB_Handle)
      return Podmander.Controller.Catalog_Entry_Vectors.Vector;
   -- Return all catalog entries where node_id IS NULL.

   function Get_Pending
     (DB : in out DB_Handle)
      return Podmander.Controller.Catalog_Entry_Vectors.Vector;
   -- Return all catalog entries where state = Pending.

   function Update_On_Success
     (DB              : in out DB_Handle;
      Id              : Integer;
      Current_Version : Podmander.Controller.Service_Version_Type)
      return Boolean;
   -- Set current_version = Current_Version, state = Deployed, update updated_at.
   -- Returns True if a row was updated, False otherwise.

   function Update_On_Failure
     (DB : in out DB_Handle; Id : Integer) return Boolean;
   -- Set state = Failed, update updated_at.
   -- Returns True if a row was updated, False otherwise.

   function Assign_Node
     (DB      : in out DB_Handle;
      Id      : Integer;
      Node_Id : Podmander.Types.Node_Id_Type) return Boolean;
   -- Set node_id = Node_Id, update updated_at.
   -- Returns True if a row was updated, False otherwise.

   function Set_Target
     (DB             : in out DB_Handle;
      Id             : Integer;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Boolean;
   -- Set target_version = Target_Version, state = Pending,
   -- update updated_at.  Returns True if a row was updated, False otherwise.

   function Set_State
     (DB : in out DB_Handle; Id : Integer; State : Catalog_Entry_State)
      return Boolean;
   --  Set state = State, update updated_at.
   --  Returns True if a row was updated, False otherwise.

   procedure Reset_In_Progress_For_Node
     (DB : in out DB_Handle; Node_Id : Podmander.Types.Node_Id_Type);
   --  Reset all In_Progress catalog entries for the given node
   --  back to Pending. Called when a node's agent reconnects to ensure
   --  any lost deploy commands are retried.

   procedure Reset_In_Progress (DB : in out DB_Handle);
   --  Reset all In_Progress entries to Pending.
   --  Called on controller startup to handle stale in-progress entries
   --  from a previous controller crash.

end Podmander.Controller.Service_Catalog.Repository;
