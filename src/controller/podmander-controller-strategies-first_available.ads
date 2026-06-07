--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  First Available scheduling strategy: selects the first agent with
--  Registered state. Returns Present => False when no eligible agent exists.
--  Stateless ; share the package-level Instance constant.

package Podmander.Controller.Strategies.First_Available is

   type First_Available_Strategy is new Strategy_Type with null record;

   overriding
   function Select_Agent
     (Strategy       : First_Available_Strategy;
      DB             : in out DB_Handle;
      Service_Id     : Service_Id_Type;
      Target_Version : Service_Version_Type) return Agent_Option;

   Instance : constant First_Available_Strategy;

private

   Instance : constant First_Available_Strategy := (null record);

end Podmander.Controller.Strategies.First_Available;
