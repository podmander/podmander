--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Pluggable agent-selection abstraction used by the Scheduler. Each concrete
--  strategy receives fleet state via DB and returns either the chosen agent or
--  nothing (no eligible agent found). The Scheduler owns persistence; the
--  strategy owns selection only.

with Podmander.Database;

package Podmander.Controller.Strategies is

   use Podmander.Database;

   type Strategy_Type is abstract tagged null record;

   function Select_Agent
     (Strategy       : Strategy_Type;
      DB             : in out DB_Handle;
      Service_Id     : Service_Id_Type;
      Target_Version : Service_Version_Type) return Agent_Option
   is abstract;

end Podmander.Controller.Strategies;
