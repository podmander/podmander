--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Types;

package body Podmander.Controller.Scheduler is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use Podmander.Types;
   use Podmander.Controller.Service_Catalog.Repository;

   --  Dummy entry returned in error cases where no real entry exists.
   Dummy_Entry : constant Podmander.Controller.Service_Catalog_Entry :=
     (Id              => 0,
      Service_Id      => Podmander.Controller.Service_Id_Type'First,
      Node_Id         => Null_Unbounded_String,
      Current_Version => 0,
      Target_Version  => Podmander.Controller.Service_Version_Type'First,
      State           => Pending,
      Updated_At      => Clock);

   ---------------
   -- Schedule --
   ---------------

   function Schedule
      (DB : in out DB_Handle; Service_Id : Podmander.Controller.Service_Id_Type;
       Target_Version : Podmander.Controller.Service_Version_Type)
       return Schedule_Result
   is
      --  Query registered agents to select a target node.
      --  MVP strategy: assign the first registered agent found.
      All_Agents     : constant Podmander.Types.Agent_Maps.Map :=
        Podmander.Controller.Agent.Repository.Load_All (DB);
      Target_Node_Id : Unbounded_String := Null_Unbounded_String;
   begin
      for Cursor in All_Agents.Iterate loop
         declare
            Info : constant Podmander.Types.Agent_Info :=
              Podmander.Types.Agent_Maps.Element (Cursor);
         begin
            if Info.State = Podmander.Types.Registered then
               Target_Node_Id := Info.Node_Id;
               exit;
            end if;
         end;
      end loop;

      declare
         Node_Id_Str : constant String := To_String (Target_Node_Id);
      begin
         --  Try to update an existing entry
         declare
            Existing : constant Podmander.Controller.Service_Catalog_Entry :=
              Get_By_Service_Id (DB, Service_Id);
            Updated  : Boolean;
            pragma Unreferenced (Updated);
         begin
            --  Entry exists â update target and clear failed
            Updated := Set_Target (DB, Existing.Id, Target_Version);

            --  Assign node if one is available
            if Node_Id_Str /= "" then
               Updated := Assign_Node (DB, Existing.Id, Node_Id_Str);
            end if;

            return
              (Ok            => True,
               Catalog_Entry => Get_By_Id (DB, Existing.Id),
               Error         => None);
         end;
      exception
         when E : Podmander.Database.Database_Error =>
            declare
               Info : constant Error_Info := Parse_Error (E);
            begin
               if Info.Kind = Not_Found then
                  --  No existing entry â create a new one
                  return
                    (Ok            => True,
                     Catalog_Entry =>
                       Create_Entry
                         (DB,
                          Service_Id     => Service_Id,
                          Node_Id        => Node_Id_Str,
                          Target_Version => Target_Version),
                     Error         => None);
               end if;
            end;
            return
              (Ok            => False,
               Catalog_Entry => Dummy_Entry,
               Error         => Database_Error);
      end;
   end Schedule;

end Podmander.Controller.Scheduler;
