--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Controller.Agent.Repository;
with Podmander.Types;

package body Podmander.Controller.Strategies.First_Available is

   use Podmander.Types;

   overriding
   function Select_Node
     (Strategy       : First_Available_Strategy;
      DB             : in out DB_Handle;
      Service_Id     : Service_Id_Type;
      Target_Version : Service_Version_Type) return Node_Option
   is
      pragma Unreferenced (Strategy, Service_Id, Target_Version);
      All_Agents : constant Podmander.Types.Agent_Maps.Map :=
        Podmander.Controller.Agent.Repository.Load_All (DB);
   begin
      for Cursor in All_Agents.Iterate loop
         declare
            Info : constant Podmander.Types.Agent_Info :=
              Podmander.Types.Agent_Maps.Element (Cursor);
         begin
            if Info.State = Podmander.Types.Registered then
               return (Present => True, Node_Id => Info.Node_Id);
            end if;
         end;
      end loop;
      return (Present => False);
   end Select_Node;

end Podmander.Controller.Strategies.First_Available;
