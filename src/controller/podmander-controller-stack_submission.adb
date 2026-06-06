--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Podmander.Config.Parser;
with Podmander.Controller.Registrar;
with Podmander.Controller.Scheduler;

package body Podmander.Controller.Stack_Submission is

   function Submit
     (DB : in out DB_Handle; TOML_Content : String) return Submission_Result
   is
      Parse_Res : constant Podmander.Config.Parser.Parse_Result :=
        Podmander.Config.Parser.Parse_Content (TOML_Content);
   begin
      if not Parse_Res.Success then
         return
           (Ok      => False,
            Error   => Parse_Failed,
            Message => Parse_Res.Message);
      end if;

      declare
         Reg_Result :
           constant Podmander.Controller.Registrar.Register_Result :=
             Podmander.Controller.Registrar.Register (DB, Parse_Res.Config);
      begin
         if not Reg_Result.Ok then
            return
              (Ok      => False,
               Error   => Registration_Failed,
               Message =>
                 To_Unbounded_String
                   ("Failed to register service "
                    & To_String (Parse_Res.Config.Name)));
         end if;

         declare
            Sched_Result :
              constant Podmander.Controller.Scheduler.Schedule_Result :=
                Podmander.Controller.Scheduler.Schedule
                  (DB,
                   Service_Id     => Reg_Result.Version.Service_Id,
                   Target_Version => Reg_Result.Version.Version);
         begin
            if not Sched_Result.Ok then
               return
                 (Ok      => False,
                  Error   => Schedule_Failed,
                  Message =>
                    To_Unbounded_String
                      ("Failed to schedule "
                       & To_String (Parse_Res.Config.Name)));
            end if;
         end;

         return
           (Ok      => True,
            Error   => None,
            Message =>
              To_Unbounded_String
                ("Scheduled " & To_String (Parse_Res.Config.Name)));
      end;
   end Submit;

end Podmander.Controller.Stack_Submission;
