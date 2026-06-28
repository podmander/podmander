--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Logging;

package Podmander.Runtime_Config_Helpers is

   function To_Log_Level (Value : String) return Podmander.Logging.Log_Level;

   function Config_Path_From_Arguments
     (Default_Path : String; Explicit : out Boolean) return String;

end Podmander.Runtime_Config_Helpers;
