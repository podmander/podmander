--  Copyright (C) 2026 Jochen Lillich
--  All rights reserved.

with Ada.Calendar;
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

end Podmander.Types;
