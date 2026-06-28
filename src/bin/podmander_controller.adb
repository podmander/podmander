--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Podmander.Args;
with Podmander.Controller;
with Podmander.Controller.Runtime_Config;
with Podmander.Logging;

procedure Podmander_Controller is
   use Ada.Strings.Unbounded;
   Token : Unbounded_String;
   function Config_Argument return String is
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if Arg = "--config" then
               if I = Ada.Command_Line.Argument_Count then
                  return "";
               end if;

               declare
                  Next : constant String := Ada.Command_Line.Argument (I + 1);
               begin
                  if Next'Length > 0 and then Next (1) /= '-' then
                     return Next;
                  end if;

                  return "";
               end;
            elsif Arg'Length >= 9 and then Arg (1 .. 9) = "--config=" then
               if Arg'Length = 9 then
                  return "";
               end if;

               return Arg (10 .. Arg'Last);
            end if;
         end;
      end loop;
      return Podmander.Controller.Runtime_Config.Default_Config_Path;
   end Config_Argument;

   function Config_Explicit return Boolean is
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         if Ada.Command_Line.Argument (I) = "--config"
           or else (Ada.Command_Line.Argument (I)'Length >= 9
                    and then Ada.Command_Line.Argument (I) (1 .. 9)
                             = "--config=")
         then
            return True;
         end if;
      end loop;
      return False;
   end Config_Explicit;

begin
   declare
      Path     : constant String := Config_Argument;
      Explicit : constant Boolean := Config_Explicit;
   begin
      if Explicit and then Path = "" then
         Podmander.Logging.Critical ("controller", "--config requires a path");
         Ada.Command_Line.Set_Exit_Status (1);
         return;
      end if;

      declare
         Load_Result :
           constant Podmander.Controller.Runtime_Config.Load_Result :=
             Podmander.Controller.Runtime_Config.Load
               (Config_Path          => Path,
                Config_Path_Explicit => Explicit,
                Bind_Override        => Podmander.Args.Get ("bind", ""),
                Log_Level_Override   => Podmander.Args.Get ("log-level", ""));
      begin
         if not Load_Result.Success then
            Podmander.Logging.Critical
              ("controller", To_String (Load_Result.Message));
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;

         Podmander.Logging.Set_Level (Load_Result.Value.Log_Level);

         declare
            Ctrl : Podmander.Controller.Controller_Instance :=
              Podmander.Controller.Make_Listening_Controller
                (Load_Result.Value.Config);
         begin
            Ctrl.Generate_Join_Token (Token);
            Podmander.Logging.Info
              ("controller", "Join token: " & To_String (Token));

            Ctrl.Run;
         end;
      end;
   end;

   Podmander.Logging.Info ("controller", "Controller stopped.");
end Podmander_Controller;
