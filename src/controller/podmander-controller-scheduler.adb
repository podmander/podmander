--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Service_Catalog.Repository;

package body Podmander.Controller.Scheduler is

   use Ada.Calendar;
   use Ada.Strings.Unbounded;
   use Podmander.Controller.Service_Catalog.Repository;

   -- Dummy entry returned in error cases where no real entry exists.
   Dummy_Entry : constant Podmander.Controller.Service_Catalog_Entry :=
     (Id              => 0,
      Service_Id      => 0,
      Node_Id         => Null_Unbounded_String,
      Current_Version => 0,
      Target_Version  => 1,
      Failed          => False,
      Updated_At      => Clock);

   ---------------
   -- Schedule
   ---------------

   function Schedule
     (DB : in out DB_Handle; Service_Id : Integer; Target_Version : Positive; Node_Id : String) return Schedule_Result
   is
   begin
      declare
         Existing : constant Podmander.Controller.Service_Catalog_Entry := Get_By_Service_Id (DB, Service_Id);
         Updated  : Boolean;
         pragma Unreferenced (Updated);
      begin
         -- Entry exists  -- update target and clear failed
         Updated := Set_Target (DB, Existing.Id, Target_Version);

         -- Assign node if one is provided
         if Node_Id /= "" then
            Updated := Assign_Node (DB, Existing.Id, Node_Id);
         end if;

         return (Ok => True, Catalog_Entry => Get_By_Id (DB, Existing.Id), Error => None);
      end;
   exception
      when E : Podmander.Database.Database_Error =>
         declare
            Info : constant Error_Info := Parse_Error (E);
         begin
            if Info.Kind = Not_Found then
               -- No existing entry  -- create a new one
               return
                 (Ok            => True,
                  Catalog_Entry =>
                    Create_Entry (DB, Service_Id => Service_Id, Node_Id => Node_Id, Target_Version => Target_Version),
                  Error         => None);
            end if;
         end;
         return (Ok => False, Catalog_Entry => Dummy_Entry, Error => Database_Error);
   end Schedule;

end Podmander.Controller.Scheduler;
