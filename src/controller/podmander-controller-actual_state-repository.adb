--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Podmander.Controller;

package body Podmander.Controller.Actual_State.Repository is

   use Ada.Strings.Unbounded;

   ------------
   --  ISO 8601
   ------------

   function Time_To_ISO8601 (T : Ada.Calendar.Time) return String is
      Raw : constant String := Ada.Calendar.Formatting.Image (T);
   begin
      return Raw (1 .. 10) & "T" & Raw (12 .. 19) & "Z";
   end Time_To_ISO8601;

   function ISO8601_To_Time (S : String) return Ada.Calendar.Time is
      Fixed : String (1 .. 19) := S (S'First .. S'First + 18);
   begin
      Fixed (11) := ' ';
      return Ada.Calendar.Formatting.Value (Fixed);
   end ISO8601_To_Time;

   ---------
   --  Row --
   ---------

   function Row_To_Entry
     (DB : in out DB_Handle; QH : in out Query_Handle)
      return Podmander.Controller.Actual_State_Entry
   is
   begin
      return
        (Service_Name => To_Unbounded_String (Column_Text (QH, 0)),
         Node_Id      => To_Unbounded_String (Column_Text (QH, 1)),
         Version      => Positive'Value (Column_Text (QH, 2)),
         Updated_At   => ISO8601_To_Time (Column_Text (QH, 3)));
   exception
      when Constraint_Error =>
         raise Database_Error
           with Format_Error
             ((Kind    => Unknown,
               Message =>
                 To_Unbounded_String
                   ("Invalid version number in actual_state"),
               Code    => 0));
   end Row_To_Entry;

   -----------
   --  Upsert
   -----------

   procedure Upsert
     (DB  : in out DB_Handle;
      Rec : Podmander.Controller.Actual_State_Entry)
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "INSERT OR REPLACE INTO actual_state "
           & "(service_name, node_id, version, updated_at) "
           & "VALUES (?, ?, ?, ?)");
   begin
      Bind_Text (QH, 1, To_String (Rec.Service_Name));
      Bind_Text (QH, 2, To_String (Rec.Node_Id));
      Bind_Text (QH, 3,
                  Ada.Strings.Fixed.Trim (Rec.Version'Image,
                                          Ada.Strings.Left));
      Bind_Text (QH, 4, Time_To_ISO8601 (Rec.Updated_At));
      while Step (QH) loop
         null;
      end loop;
   end Upsert;

   ------------
   --  Get_All
   ------------

   function Get_All
     (DB : in out DB_Handle)
      return Podmander.Controller.Actual_State_Vectors.Vector
   is
      QH  : Query_Handle :=
        Prepare
          (DB,
           "SELECT service_name, node_id, version, updated_at "
           & "FROM actual_state");
      Result : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      while Step (QH) loop
         Result.Append (Row_To_Entry (DB, QH));
      end loop;
      return Result;
   end Get_All;

   --------------------
   --  Get_For_Service
   --------------------

   function Get_For_Service
     (DB           : in out DB_Handle;
      Service_Name : String)
      return Podmander.Controller.Actual_State_Vectors.Vector
   is
      QH  : Query_Handle :=
        Prepare
          (DB,
           "SELECT service_name, node_id, version, updated_at "
           & "FROM actual_state WHERE service_name = ?");
      Result : Podmander.Controller.Actual_State_Vectors.Vector;
   begin
      Bind_Text (QH, 1, Service_Name);
      while Step (QH) loop
         Result.Append (Row_To_Entry (DB, QH));
      end loop;
      return Result;
   end Get_For_Service;

   -------------
   --  Remove
   -------------

   procedure Remove
     (DB           : in out DB_Handle;
      Service_Name : String;
      Node_Id      : String)
   is
      QH : Query_Handle :=
        Prepare
          (DB,
           "DELETE FROM actual_state "
           & "WHERE service_name = ? AND node_id = ?");
   begin
      Bind_Text (QH, 1, Service_Name);
      Bind_Text (QH, 2, Node_Id);
      while Step (QH) loop
         null;
      end loop;
   end Remove;

end Podmander.Controller.Actual_State.Repository;
