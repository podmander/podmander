--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package Podmander.Logging is

   type Log_Level is (Debug, Info, Warning, Error, Critical);

   procedure Set_Level (Level : Log_Level);

   function Get_Level return Log_Level;

   procedure Debug    (Component : String; Message : String);
   procedure Info     (Component : String; Message : String);
   procedure Warning  (Component : String; Message : String);
   procedure Error    (Component : String; Message : String);
   procedure Critical (Component : String; Message : String);

end Podmander.Logging;