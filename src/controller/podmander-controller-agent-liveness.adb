--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Agent.Repository;
with Podmander.Logging;
with Podmander.Types;

package body Podmander.Controller.Agent.Liveness is

   use Ada.Strings.Unbounded;
   use Podmander.Types;

   procedure Check_Timeouts
     (DB : in out Podmander.Database.DB_Handle; Agent_Timeout : Duration)
   is
      use type Ada.Calendar.Time;
      Now                    : constant Ada.Calendar.Time :=
        Ada.Calendar.Clock;
      Unresponsive_Threshold : constant Duration := Agent_Timeout * 2.0;
      Lost_Threshold         : constant Duration := Agent_Timeout * 3.0;
      All_Agents             : constant Podmander.Types.Agent_Maps.Map :=
        Agent.Repository.Load_All (DB);
   begin
      for Cursor in All_Agents.Iterate loop
         declare
            Info    : Podmander.Types.Agent_Info :=
              Podmander.Types.Agent_Maps.Element (Cursor);
            Name    : constant String := To_String (Info.Name);
            Elapsed : constant Duration := Now - Info.Last_Seen;
         begin
            if Elapsed >= Lost_Threshold
              and then Info.State /= Podmander.Types.Lost
            then
               Info.State := Podmander.Types.Lost;
               Agent.Repository.Set_State (DB, Info);
               Podmander.Logging.Warning
                 ("liveness", "Agent " & Name & " disconnected");
            elsif Elapsed >= Unresponsive_Threshold
              and then Info.State = Podmander.Types.Registered
            then
               Info.State := Podmander.Types.Unresponsive;
               Agent.Repository.Set_State (DB, Info);
               Podmander.Logging.Warning
                 ("liveness", "Agent " & Name & " unresponsive");
            end if;
         end;
      end loop;
   end Check_Timeouts;

   procedure Recover (DB : in out Podmander.Database.DB_Handle) is
      All_Agents : constant Podmander.Types.Agent_Maps.Map :=
        Agent.Repository.Load_All (DB);
   begin
      for Cursor in All_Agents.Iterate loop
         declare
            Info : Podmander.Types.Agent_Info :=
              Podmander.Types.Agent_Maps.Element (Cursor);
         begin
            if Info.State /= Podmander.Types.Lost then
               Info.State := Podmander.Types.Unresponsive;
               Agent.Repository.Set_State (DB, Info);
            end if;
         end;
      end loop;
   end Recover;

end Podmander.Controller.Agent.Liveness;
