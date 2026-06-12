--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Types;

package body Podmander.Controller.Scheduler is

   use Ada.Calendar;
   use Podmander.Controller.Service_Catalog.Repository;
   use Podmander.Types;

   --  Dummy entry returned in error cases where no real entry exists.
   Dummy_Entry : constant Podmander.Controller.Service_Catalog_Entry :=
     (Id              => 0,
      Service_Id      => Podmander.Controller.Service_Id_Type'First,
      Node_Id         => 0,
      Current_Version => (Present => False),
      Target_Version  => Podmander.Controller.Service_Version_Type'First,
      State           => Pending,
      Updated_At      => Clock);

   ---------------
   -- Schedule --
   ---------------

   function Schedule
     (DB             : in out DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Target_Version : Podmander.Controller.Service_Version_Type;
      Strategy       : Podmander.Controller.Strategies.Strategy_Type'Class)
      return Schedule_Result
   is
      Selected       : constant Podmander.Controller.Node_Option :=
        Strategy.Select_Node (DB, Service_Id, Target_Version);
      Target_Node_Id : constant Node_Id_Type :=
        (if Selected.Present then Selected.Node_Id else 0);
   begin
      begin
         --  Try to update an existing entry
         declare
            Existing : constant Podmander.Controller.Service_Catalog_Entry :=
              Get_By_Service_Id (DB, Service_Id);
            Updated  : Boolean;
            pragma Unreferenced (Updated);
         begin
            Updated := Set_Target (DB, Existing.Id, Target_Version);

            if Target_Node_Id /= 0 then
               Updated := Assign_Node (DB, Existing.Id, Target_Node_Id);
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
                  return
                    (Ok            => True,
                     Catalog_Entry =>
                       Create_Entry
                         (DB,
                          Service_Id     => Service_Id,
                          Node_Id        => Target_Node_Id,
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
