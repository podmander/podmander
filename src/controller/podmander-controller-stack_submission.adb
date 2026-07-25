--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Fixed;

with Podmander.Config.Parser;
with Podmander.Controller.Service.Json_Utils;
with Podmander.Controller.Registrar;
with Podmander.Controller.Scheduler;
with Podmander.Controller.Strategies.First_Available;

package body Podmander.Controller.Stack_Submission is

   package Json_Utils renames Podmander.Controller.Service.Json_Utils;

   function Network_Conflict
     (DB : in out DB_Handle; Definition : Podmander.Config.Service_Definition)
      return String
   is
      QH             : Query_Handle :=
        Prepare
          (DB,
           "SELECT s.name, sv.ports, sv.named_ports, sv.ingress_host "
           & "FROM service_catalog c "
           & "JOIN services s ON s.id = c.service_id "
           & "JOIN service_versions sv ON sv.service_id = c.service_id "
           & "AND (sv.version = c.target_version OR "
           & "(c.current_version IS NOT NULL AND sv.version = c.current_version))");
      Candidate_Name : constant String := To_String (Definition.Service_Name);
      function Host_Used (Host : Port_Number; Text : String) return Boolean is
         Ports : Port_Array (1 .. MAX_PORTS_ENTRIES);
         Count : Natural;
      begin
         Json_Utils.Parse_Port_Array (Text, Ports, Count);
         for I in 1 .. Count loop
            if Ports (I).Host = Host then
               return True;
            end if;
         end loop;
         return False;
      exception
         when Json_Utils.Parse_Error =>
            raise Podmander.Database.Database_Error
              with "Malformed persisted network JSON";
      end Host_Used;
      function Named_Host_Used
        (Host : Port_Number; Text : String) return Boolean
      is
         Ports : Named_Port_Array (1 .. MAX_NAMED_PORTS_ENTRIES);
         Count : Natural;
      begin
         Json_Utils.Parse_Named_Port_Array (Text, Ports, Count);
         for I in 1 .. Count loop
            if Ports (I).Host = Host then
               return True;
            end if;
         end loop;
         return False;
      exception
         when Json_Utils.Parse_Error =>
            raise Podmander.Database.Database_Error
              with "Malformed persisted network JSON";
      end Named_Host_Used;
   begin
      for I in 1 .. Definition.Named_Ports_Count loop
         for J in I + 1 .. Definition.Named_Ports_Count loop
            if Definition.Named_Ports (I).Host
              = Definition.Named_Ports (J).Host
            then
               return "duplicate published host port";
            end if;
         end loop;
      end loop;
      for I in 1 .. Definition.Ports_Count loop
         for J in I + 1 .. Definition.Ports_Count loop
            if Definition.Ports (I).Host = Definition.Ports (J).Host then
               return "duplicate published host port";
            end if;
         end loop;
      end loop;

      while Step (QH) loop
         declare
            Other_Name : constant String := Column_Text (QH, 0);
            Other_Host : constant String := Column_Text (QH, 3);
         begin
            if Other_Name /= Candidate_Name then
               if Length (Definition.Ingress.Host) > 0
                 and then Other_Host = To_String (Definition.Ingress.Host)
               then
                  return
                    "Ingress host '"
                    & To_String (Definition.Ingress.Host)
                    & "' is already reserved by service '"
                    & Other_Name
                    & "'";
               end if;
               for I in 1 .. Definition.Named_Ports_Count loop
                  if Host_Used
                       (Definition.Named_Ports (I).Host, Column_Text (QH, 1))
                    or else Named_Host_Used
                              (Definition.Named_Ports (I).Host,
                               Column_Text (QH, 2))
                  then
                     return
                       "Host port '"
                       & Ada.Strings.Fixed.Trim
                           (Port_Number'Image
                              (Definition.Named_Ports (I).Host),
                            Ada.Strings.Left)
                       & "' is already reserved by service '"
                       & Other_Name
                       & "'";
                  end if;
               end loop;
               for I in 1 .. Definition.Ports_Count loop
                  if Host_Used (Definition.Ports (I).Host, Column_Text (QH, 1))
                    or else Named_Host_Used
                              (Definition.Ports (I).Host, Column_Text (QH, 2))
                  then
                     return
                       "Host port '"
                       & Ada.Strings.Fixed.Trim
                           (Port_Number'Image (Definition.Ports (I).Host),
                            Ada.Strings.Left)
                       & "' is already reserved by service '"
                       & Other_Name
                       & "'";
                  end if;
               end loop;
            end if;
         end;
      end loop;
      return "";
   end Network_Conflict;

   function Submit
     (DB : in out DB_Handle; TOML_Content : String) return Submission_Result
   is
      Parse_Res            : constant Podmander.Config.Parser.Parse_Result :=
        Podmander.Config.Parser.Parse_Content (TOML_Content);
      In_Transaction       : Boolean := False;
      Rollback_In_Progress : Boolean := False;

      procedure Rollback is
      begin
         if In_Transaction then
            Rollback_In_Progress := True;
            Execute (DB, "ROLLBACK");
            In_Transaction := False;
            Rollback_In_Progress := False;
         end if;
      end Rollback;
   begin
      if not Parse_Res.Success then
         return
           (Ok => False, Error => Parse_Failed, Message => Parse_Res.Message);
      end if;

      begin
         Execute (DB, "BEGIN");
         In_Transaction := True;

         declare
            Conflict : constant String :=
              Network_Conflict (DB, Parse_Res.Config);
         begin
            if Conflict'Length > 0 then
               Rollback;
               return
                 (Ok      => False,
                  Error   => Registration_Failed,
                  Message => To_Unbounded_String (Conflict));
            end if;
         end;

         declare
            Reg_Result :
              constant Podmander.Controller.Registrar.Register_Result :=
                Podmander.Controller.Registrar.Register (DB, Parse_Res.Config);
         begin
            if not Reg_Result.Ok then
               Rollback;
               return
                 (Ok      => False,
                  Error   => Registration_Failed,
                  Message =>
                    To_Unbounded_String
                      ("Failed to register service "
                       & To_String (Parse_Res.Config.Service_Name)
                       & ": "
                       & Reg_Result.Error'Image));
            end if;

            declare
               Sched_Result :
                 constant Podmander.Controller.Scheduler.Schedule_Result :=
                   Podmander.Controller.Scheduler.Schedule
                     (DB,
                      Service_Id     => Reg_Result.Version.Service_Id,
                      Target_Version => Reg_Result.Version.Version,
                      Strategy       =>
                        Podmander
                          .Controller
                          .Strategies
                          .First_Available
                          .Instance);
            begin
               if not Sched_Result.Ok then
                  Rollback;
                  return
                    (Ok      => False,
                     Error   => Schedule_Failed,
                     Message =>
                       To_Unbounded_String
                         ("Failed to schedule "
                          & To_String (Parse_Res.Config.Service_Name)
                          & ": "
                          & Sched_Result.Error'Image));
               end if;
            end;
         end;

         Execute (DB, "COMMIT");
         In_Transaction := False;

         return
           (Ok      => True,
            Error   => None,
            Message =>
              To_Unbounded_String
                ("Scheduled " & To_String (Parse_Res.Config.Service_Name)));
      exception
         when Podmander.Database.Database_Error =>
            if Rollback_In_Progress then
               raise;
            end if;
            Rollback;
            return
              (Ok      => False,
               Error   => Registration_Failed,
               Message =>
                 To_Unbounded_String
                   ("Failed to submit service: database error"));
      end;
   end Submit;

end Podmander.Controller.Stack_Submission;
