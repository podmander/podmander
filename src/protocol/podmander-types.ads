--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

package Podmander.Types is

   type Connection_State is (Disconnected, Enrolling, Connected);

   type Agent_State is (Registered, Unresponsive, Lost);

   type Node_Id_Type is new Natural;
   --  Row identifier in the nodes table. 0 means unassigned (no node
   --  has been linked yet). Negative node IDs are not representable.
   --  Distinct from Integer so a generic integer
   --  cannot be passed by mistake.

   Unassigned_Node_Id : constant Node_Id_Type := 0;

   subtype Agent_Id_Type is Natural;
   --  Row identifier in the agents table. 0 means unassigned before
   --  the agent record has been persisted.

   Unassigned_Agent_Id : constant Agent_Id_Type := 0;

   type Node_Info is record
      Id   : Node_Id_Type := Unassigned_Node_Id;
      Name : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Agent_Info is record
      Id            : Agent_Id_Type := Unassigned_Agent_Id;
      Name          : Ada.Strings.Unbounded.Unbounded_String;
      Connection_Id : Ada.Strings.Unbounded.Unbounded_String;
      State         : Agent_State := Registered;
      Last_Seen     : Ada.Calendar.Time;
      Node_Id       : Node_Id_Type := 0;
   end record;

   package Agent_Maps is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => String,
        Element_Type    => Agent_Info,
        Hash            => Ada.Strings.Hash,
        Equivalent_Keys => "=");

end Podmander.Types;
