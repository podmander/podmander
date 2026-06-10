--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Pluggable node-selection abstraction used by the Scheduler. Each concrete
--  strategy receives fleet state via DB and returns either the chosen node or
--  nothing (no eligible node found). The Scheduler owns persistence; the
--  strategy owns selection only.

with Podmander.Database;

package Podmander.Controller.Strategies is

   use Podmander.Database;

   type Strategy_Type is abstract tagged null record;

   function Select_Node
     (Strategy       : Strategy_Type;
      DB             : in out DB_Handle;
      Service_Id     : Service_Id_Type;
      Target_Version : Service_Version_Type) return Node_Option
   is abstract;

end Podmander.Controller.Strategies;
