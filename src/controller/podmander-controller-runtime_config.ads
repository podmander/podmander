--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.Logging;

package Podmander.Controller.Runtime_Config is

   use Ada.Strings.Unbounded;

   type Config_Overrides is record
      Bind      : Unbounded_String := Null_Unbounded_String;
      Log_Level : Unbounded_String := Null_Unbounded_String;
   end record;

   Default_Overrides : constant Config_Overrides :=
     (others => Null_Unbounded_String);

   Default_Config_Path : constant String := "/etc/podmander/controller.toml";

   type Runtime_Config is record
      Config    : Podmander.Controller.Controller_Config;
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
      Overrides            : Config_Overrides := Default_Overrides)
      return Load_Result;

end Podmander.Controller.Runtime_Config;
