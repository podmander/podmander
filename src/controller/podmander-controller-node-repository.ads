--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Database;
with Podmander.Types;

package Podmander.Controller.Node.Repository is

   use Podmander.Database;
   use Podmander.Types;

   function Create_Or_Get
     (DB : in out DB_Handle; Machine_Name : String) return Node_Id_Type;
   --  Ensure a Node exists for the given machine name. If one already
   --  exists, return its id; otherwise create it and return the new id.
   --  The machine name must be unique across all nodes.

   function Load_By_Name
     (DB : in out DB_Handle; Machine_Name : String) return Node_Id_Type;
   --  Return the id of the node with the given machine name.
   --  Raises Database_Error with Not_Found if no such node exists.

end Podmander.Controller.Node.Repository;
