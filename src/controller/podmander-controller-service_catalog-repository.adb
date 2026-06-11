--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Podmander.Database.Time_Utils;

package body Podmander.Controller.Service_Catalog.Repository is

   use Ada.Strings.Unbounded;
   use Podmander.Database.Time_Utils;
   use Podmander.Types;

   ---------------
   -- Row to entry
   ---------------

   function Row_To_Entry
     (DB : in out DB_Handle; QH : in out Query_Handle)
      return Podmander.Controller.Service_Catalog_Entry
   is
      pragma Unreferenced (DB);
   begin
      return
        (Id              => Column_Int (QH, 0),
         Service_Id      =>
           Podmander.Controller.Service_Id_Type (Column_Int (QH, 1)),
         Node_Id         => Node_Id_Type (Column_Int (QH, 2)),
         Current_Version => Column_Int (QH, 3),
         Target_Version  =>
           Podmander.Controller.Service_Version_Type (Column_Int (QH, 4)),
         State           => Catalog_Entry_State'Val (Column_Int (QH, 5)),
         Updated_At      => ISO8601_To_Time (Column_Text (QH, 6)));
   exception
      when Constraint_Error =>
         raise Database_Error
           with
             Format_Error
               ((Kind    => Unknown,
                 Message =>
                   To_Unbounded_String
                     ("Invalid target_version in service_catalog"),
                 Code    => 0));
   end Row_To_Entry;

   -----------------
   -- Create_Entry
   -----------------

   function Create_Entry
     (DB             : in out DB_Handle;
      Service_Id     : Podmander.Controller.Service_Id_Type;
      Node_Id        : Node_Id_Type := 0;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Podmander.Controller.Service_Catalog_Entry
   is
      Now_Str : constant String := Time_To_ISO8601 (Ada.Calendar.Clock);
      QH      : Query_Handle :=
        Prepare
          (DB,
           "INSERT INTO service_catalog "
           & "(service_id, node_id, target_version, updated_at) "
           & "VALUES (?, ?, ?, ?)");
      SEL     : Query_Handle :=
        Prepare
          (DB,
           "SELECT id, service_id, node_id, current_version, "
           & "target_version, state, updated_at "
           & "FROM service_catalog WHERE id = last_insert_rowid()");
   begin
      Bind_Int (QH, 1, Integer (Service_Id));
      if Node_Id = 0 then
         Bind_Null (QH, 2);
      else
         Bind_Int (QH, 2, Integer (Node_Id));
      end if;
      Bind_Int (QH, 3, Integer (Target_Version));
      Bind_Text (QH, 4, Now_Str);
      while Step (QH) loop
         null;
      end loop;

      if Step (SEL) then
         return Row_To_Entry (DB, SEL);
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Unknown,
                 Message =>
                   To_Unbounded_String
                     ("Failed to retrieve service_catalog entry after insert"),
                 Code    => 0));
      end if;
   end Create_Entry;

   ---------------
   -- Get_By_Id
   ---------------

   function Get_By_Id
     (DB : in out DB_Handle; Id : Integer)
      return Podmander.Controller.Service_Catalog_Entry
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "SELECT id, service_id, node_id, current_version, "
           & "target_version, state, updated_at "
           & "FROM service_catalog WHERE id = ?");
   begin
      Bind_Int (QH, 1, Id);
      if Step (QH) then
         return Row_To_Entry (DB, QH);
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Not_Found,
                 Message =>
                   To_Unbounded_String
                     ("Service catalog entry not found: "
                      & Ada.Strings.Fixed.Trim (Id'Image, Ada.Strings.Left)),
                 Code    => 0));
      end if;
   end Get_By_Id;

   -----------------------
   -- Get_By_Service_Id
   -----------------------

   function Get_By_Service_Id
     (DB : in out DB_Handle; Service_Id : Podmander.Controller.Service_Id_Type)
      return Podmander.Controller.Service_Catalog_Entry
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "SELECT id, service_id, node_id, current_version, "
           & "target_version, state, updated_at "
           & "FROM service_catalog WHERE service_id = ? LIMIT 1");
   begin
      Bind_Int (QH, 1, Integer (Service_Id));
      if Step (QH) then
         return Row_To_Entry (DB, QH);
      else
         raise Database_Error
           with
             Format_Error
               ((Kind    => Not_Found,
                 Message =>
                   To_Unbounded_String
                     ("Service catalog entry not found for service_id: "
                      & Ada.Strings.Fixed.Trim
                          (Service_Id'Image, Ada.Strings.Left)),
                 Code    => 0));
      end if;
   end Get_By_Service_Id;

   --------------------
   -- Get_Unscheduled
   --------------------

   function Get_Unscheduled
     (DB : in out DB_Handle)
      return Podmander.Controller.Catalog_Entry_Vectors.Vector
   is
      QH     : Query_Handle :=
        Prepare
          (DB,
           "SELECT id, service_id, node_id, current_version, "
           & "target_version, state, updated_at "
           & "FROM service_catalog WHERE node_id IS NULL");
      Result : Podmander.Controller.Catalog_Entry_Vectors.Vector;
   begin
      while Step (QH) loop
         Result.Append (Row_To_Entry (DB, QH));
      end loop;
      return Result;
   end Get_Unscheduled;

   ---------------
   -- Get_Pending
   ---------------

   function Get_Pending
     (DB : in out DB_Handle)
      return Podmander.Controller.Catalog_Entry_Vectors.Vector
   is
      QH     : Query_Handle :=
        Prepare
          (DB,
           "SELECT id, service_id, node_id, current_version, "
           & "target_version, state, updated_at "
           & "FROM service_catalog "
           & "WHERE state = 0");
      Result : Podmander.Controller.Catalog_Entry_Vectors.Vector;
   begin
      while Step (QH) loop
         Result.Append (Row_To_Entry (DB, QH));
      end loop;
      return Result;
   end Get_Pending;

   ----------------------
   -- Update_On_Success
   ----------------------

   function Update_On_Success
     (DB : in out DB_Handle; Id : Integer; Current_Version : Natural)
      return Boolean
   is
      Now_Str : constant String := Time_To_ISO8601 (Ada.Calendar.Clock);
      QH      : Query_Handle :=
        Prepare
          (DB,
           "UPDATE service_catalog "
           & "SET current_version = ?, state = 3, updated_at = ? "
           & "WHERE id = ?");
   begin
      Bind_Int (QH, 1, Integer (Current_Version));
      Bind_Text (QH, 2, Now_Str);
      Bind_Int (QH, 3, Id);
      while Step (QH) loop
         null;
      end loop;
      return Changes (DB) > 0;
   end Update_On_Success;

   ----------------------
   -- Update_On_Failure
   ----------------------

   function Update_On_Failure
     (DB : in out DB_Handle; Id : Integer) return Boolean
   is
      Now_Str : constant String := Time_To_ISO8601 (Ada.Calendar.Clock);
      QH      : Query_Handle :=
        Prepare
          (DB,
           "UPDATE service_catalog "
           & "SET state = 2, updated_at = ? "
           & "WHERE id = ?");
   begin
      Bind_Text (QH, 1, Now_Str);
      Bind_Int (QH, 2, Id);
      while Step (QH) loop
         null;
      end loop;
      return Changes (DB) > 0;
   end Update_On_Failure;

   -----------------
   -- Assign_Node
   -----------------

   function Assign_Node
     (DB      : in out DB_Handle;
      Id      : Integer;
      Node_Id : Node_Id_Type) return Boolean
   is
      Now_Str : constant String := Time_To_ISO8601 (Ada.Calendar.Clock);
      QH      : Query_Handle :=
        Prepare
          (DB,
           "UPDATE service_catalog "
           & "SET node_id = ?, updated_at = ? "
           & "WHERE id = ?");
   begin
      Bind_Int (QH, 1, Integer (Node_Id));
      Bind_Text (QH, 2, Now_Str);
      Bind_Int (QH, 3, Id);
      while Step (QH) loop
         null;
      end loop;
      return Changes (DB) > 0;
   end Assign_Node;

   ----------------
   -- Set_State --
   ----------------

   function Set_State
     (DB : in out DB_Handle; Id : Integer; State : Catalog_Entry_State)
      return Boolean
   is
      Now_Str : constant String := Time_To_ISO8601 (Ada.Calendar.Clock);
      QH      : Query_Handle :=
        Prepare
          (DB,
           "UPDATE service_catalog "
           & "SET state = ?, updated_at = ? "
           & "WHERE id = ?");
   begin
      Bind_Int (QH, 1, Catalog_Entry_State'Pos (State));
      Bind_Text (QH, 2, Now_Str);
      Bind_Int (QH, 3, Id);
      while Step (QH) loop
         null;
      end loop;
      return Changes (DB) > 0;
   end Set_State;

   --------------------------------
   -- Reset_In_Progress_For_Node --
   --------------------------------

   procedure Reset_In_Progress_For_Node
     (DB : in out DB_Handle; Node_Id : Node_Id_Type)
   is
      Now_Str : constant String := Time_To_ISO8601 (Ada.Calendar.Clock);
      QH      : Query_Handle :=
        Prepare
          (DB,
           "UPDATE service_catalog "
           & "SET state = 0, updated_at = ? "
           & "WHERE node_id = ? AND state = 1");
   begin
      Bind_Text (QH, 1, Now_Str);
      Bind_Int (QH, 2, Integer (Node_Id));
      while Step (QH) loop
         null;
      end loop;
   end Reset_In_Progress_For_Node;

   -------------------------
   -- Reset_In_Progress --
   -------------------------

   procedure Reset_In_Progress (DB : in out DB_Handle) is
      Now_Str : constant String := Time_To_ISO8601 (Ada.Calendar.Clock);
      QH      : Query_Handle :=
        Prepare
          (DB,
           "UPDATE service_catalog "
           & "SET state = 0, updated_at = ? "
           & "WHERE state = 1");
   begin
      Bind_Text (QH, 1, Now_Str);
      while Step (QH) loop
         null;
      end loop;
   end Reset_In_Progress;

   ---------------
   -- Set_Target
   ---------------

   function Set_Target
     (DB             : in out DB_Handle;
      Id             : Integer;
      Target_Version : Podmander.Controller.Service_Version_Type)
      return Boolean
   is
      Now_Str : constant String := Time_To_ISO8601 (Ada.Calendar.Clock);
      QH      : Query_Handle :=
        Prepare
          (DB,
           "UPDATE service_catalog "
           & "SET target_version = ?, state = 0, updated_at = ? "
           & "WHERE id = ?");
   begin
      Bind_Int (QH, 1, Integer (Target_Version));
      Bind_Text (QH, 2, Now_Str);
      Bind_Int (QH, 3, Id);
      while Step (QH) loop
         null;
      end loop;
      return Changes (DB) > 0;
   end Set_Target;

end Podmander.Controller.Service_Catalog.Repository;
