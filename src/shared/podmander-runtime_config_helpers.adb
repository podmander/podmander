--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Command_Line;

package body Podmander.Runtime_Config_Helpers is

   function To_Log_Level (Value : String) return Podmander.Logging.Log_Level is
   begin
      if Value = "debug" then
         return Podmander.Logging.Debug;
      elsif Value = "info" then
         return Podmander.Logging.Info;
      elsif Value = "warning" then
         return Podmander.Logging.Warning;
      elsif Value = "error" then
         return Podmander.Logging.Error;
      elsif Value = "critical" then
         return Podmander.Logging.Critical;
      end if;

      raise Constraint_Error;
   end To_Log_Level;

   function Config_Path_From_Arguments
     (Default_Path : String; Explicit : out Boolean) return String is
   begin
      Explicit := False;
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if Arg = "--config" then
               Explicit := True;
               if I = Ada.Command_Line.Argument_Count then
                  return "";
               end if;

               declare
                  Next : constant String := Ada.Command_Line.Argument (I + 1);
               begin
                  if Next'Length > 0 and then Next (1) /= '-' then
                     return Next;
                  end if;
               end;
               return "";
            elsif Arg'Length >= 9 and then Arg (1 .. 9) = "--config=" then
               Explicit := True;
               return (if Arg'Length = 9 then "" else Arg (10 .. Arg'Last));
            end if;
         end;
      end loop;
      return Default_Path;
   end Config_Path_From_Arguments;

end Podmander.Runtime_Config_Helpers;
