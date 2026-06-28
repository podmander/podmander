--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.Logging;

package Podmander.Agent.Runtime_Config is

   use Ada.Strings.Unbounded;

   Default_Config_Path : constant String := "/etc/podmander/agent.toml";

   type Runtime_Config is record
      Config    : Podmander.Agent.Agent_Config;
      Log_Level : Podmander.Logging.Log_Level := Podmander.Logging.Info;
   end record;

   type Load_Result (Success : Boolean) is record
      case Success is
         when True =>
            Value : Runtime_Config;

         when False =>
            Message : Unbounded_String;
      end case;
   end record;

   function Load
     (Config_Path          : String := Default_Config_Path;
      Config_Path_Explicit : Boolean := False;
      Connect_Override     : String := "";
      Token_Override       : String := "";
      Name_Override        : String := "";
      Interval_Override    : String := "";
      Log_Level_Override   : String := "") return Load_Result;

end Podmander.Agent.Runtime_Config;
