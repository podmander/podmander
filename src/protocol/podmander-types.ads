--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

package Podmander.Types is

   type Connection_State is (Disconnected, Enrolling, Connected);

   type Agent_State is (Registered, Unresponsive, Lost);

   type Agent_Info is record
      Name      : Ada.Strings.Unbounded.Unbounded_String;
      Node_Id   : Ada.Strings.Unbounded.Unbounded_String;
      State     : Agent_State := Registered;
      Last_Seen : Ada.Calendar.Time;
   end record;

   package Agent_Maps is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => String,
        Element_Type    => Agent_Info,
        Hash            => Ada.Strings.Hash,
        Equivalent_Keys => "=");

end Podmander.Types;
