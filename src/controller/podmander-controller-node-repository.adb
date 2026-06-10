--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.Types;

package body Podmander.Controller.Node.Repository is

   use Ada.Strings.Unbounded;
   use Podmander.Types;

   -------------------
   -- Create_Or_Get --
   -------------------

   function Create_Or_Get
      (DB : in out DB_Handle; Machine_Name : String) return Node_Id_Type
   is
   begin
      --  Try to insert a new node. If the machine_name already exists,
      --  the UNIQUE constraint will fire; catch that and select instead.
      begin
         declare
            QH : Query_Handle :=
              Prepare (DB, "INSERT INTO nodes (machine_name) VALUES (?)");
         begin
            Bind_Text (QH, 1, Machine_Name);
            while Step (QH) loop
               null;  --  INSERT returns no rows
            end loop;
         end;

         --  Insert succeeded: fetch the new row id.
         declare
            QH : Query_Handle := Prepare (DB, "SELECT last_insert_rowid()");
         begin
            if Step (QH) then
               return Node_Id_Type (Column_Int (QH, 0));
            else
               raise Database_Error
                 with
                   Format_Error
                     ((Kind    => Unknown,
                       Message =>
                         To_Unbounded_String
                           ("Failed to get last_insert_rowid for node"),
                       Code    => 0));
            end if;
         end;
      exception
         when Database_Error =>
            --  UNIQUE constraint violation: node already exists.
            --  Select the existing id by name.
            declare
               QH : Query_Handle :=
                 Prepare (DB, "SELECT id FROM nodes WHERE machine_name = ?");
            begin
               Bind_Text (QH, 1, Machine_Name);
               if Step (QH) then
                  return Node_Id_Type (Column_Int (QH, 0));
               else
                  raise Database_Error
                    with
                      Format_Error
                        ((Kind    => Not_Found,
                          Message =>
                            To_Unbounded_String
                              ("Node not found after create-or-get: "
                               & Machine_Name),
                          Code    => 0));
               end if;
            end;
      end;
   end Create_Or_Get;

   ------------------
   -- Load_By_Name --
   ------------------

   function Load_By_Name
      (DB : in out DB_Handle; Machine_Name : String) return Node_Id_Type
   is
      QH : Query_Handle :=
        Prepare (DB, "SELECT id FROM nodes WHERE machine_name = ?");
   begin
      Bind_Text (QH, 1, Machine_Name);
      if Step (QH) then
         return Node_Id_Type (Column_Int (QH, 0));
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Not_Found,
                 Message =>
                   To_Unbounded_String ("Node not found: " & Machine_Name),
                 Code    => 0));
      end if;
   end Load_By_Name;

end Podmander.Controller.Node.Repository;
