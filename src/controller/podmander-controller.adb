--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Environment_Variables;
with CZMQ.Messages;
with CZMQ.Pollers;
with Podmander.Config.Parser;
with Podmander.Types;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Message_Handlers;
with Podmander.Controller.Registrar;
with Podmander.Controller.Scheduler;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Generators.Quadlet;
with Podmander.Logging;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Deploy_Commands;
with CZMQ.Signals;

package body Podmander.Controller is

   use Ada.Strings.Unbounded;
   use Podmander.Types;
   use type CZMQ.Messages.Receive_Status;
   use type Podmander.Database.Error_Kind;

   procedure Reconcile_State (Self : in out Controller_Instance);

   Poll_Interval_Ms : constant := 1000;

   procedure Set_Bind_Address
     (Config : in out Controller_Config; Address : String) is
   begin
      Config.Bind_Address (1 .. Address'Length) := Address;
      Config.Bind_Address_Last := Address'Length;
   end Set_Bind_Address;

   function Get_Bind_Address (Config : Controller_Config) return String is
   begin
      return Config.Bind_Address (1 .. Config.Bind_Address_Last);
   end Get_Bind_Address;

   procedure Set_DB_Path (Config : in out Controller_Config; Path : String) is
   begin
      Config.DB_Path := To_Unbounded_String (Path);
   end Set_DB_Path;

   function Get_DB_Path (Config : Controller_Config) return String is
   begin
      return To_String (Config.DB_Path);
   end Get_DB_Path;

   function Make_Listening_Controller
     (Config : Controller_Config) return Controller_Instance
   is
      DB_Path : constant String :=
        (if Get_DB_Path (Config) = ""
         then
           Ada.Environment_Variables.Value ("HOME")
           & "/.local/share/podmander/state.db"
         else Get_DB_Path (Config));
   begin
      return
         C : Controller_Instance :=
           (Config      => Config,
            DB          => Database.Open (DB_Path),
            Certificate => <>,
            Socket      => <>,
            Running     => True)
      do
         -- Per ADR-0037: agents that were Registered or Unresponsive
         -- start as Unresponsive  -- they must send a heartbeat to prove
         -- they're still alive after the controller restart.
         declare
            All_Agents : constant Podmander.Types.Agent_Maps.Map :=
              Agent.Repository.Load_All (C.DB);
         begin
            for Cursor in All_Agents.Iterate loop
               declare
                  Info : Podmander.Types.Agent_Info :=
                    Podmander.Types.Agent_Maps.Element (Cursor);
               begin
                  if Info.State /= Podmander.Types.Lost then
                     Info.State := Podmander.Types.Unresponsive;
                     Agent.Repository.Set_State (C.DB, Info);
                  end if;
               end;
            end loop;
         end;

         --  Reset any catalog entries that were In_Progress when the
         --  controller last ran. They need to be redeployed.
         declare
            use Podmander.Controller.Service_Catalog.Repository;
         begin
            Reset_In_Progress (C.DB);
         end;

         -- Load or generate CURVE certificate
         declare
            Cert_Path : constant String :=
              Ada.Directories.Containing_Directory (DB_Path)
              & "/controller.crt";
         begin
            if Ada.Directories.Exists (Cert_Path) then
               C.Certificate.Load (Cert_Path);
               Podmander.Logging.Info
                 ("controller", "Loaded CURVE certificate from " & Cert_Path);
            else
               C.Certificate.Generate;
               C.Certificate.Save (Cert_Path);
               Podmander.Logging.Info
                 ("controller",
                  "Generated and saved CURVE certificate to " & Cert_Path);
            end if;
         end;

         -- Load or generate registration secret
         declare
            use Podmander.Database;
         begin
            C.Config.Enrollment.Secret :=
              Ada.Strings.Unbounded.To_Unbounded_String
                (Get_Setting (C.DB, "registration_secret"));
            Podmander.Logging.Info
              ("controller", "Loaded registration secret from DB");
         exception
            when E : Database_Error =>
               if Parse_Error (E).Kind = Not_Found then
                  -- First start: generate and persist a new secret
                  declare
                     Token : Ada.Strings.Unbounded.Unbounded_String;
                  begin
                     Podmander.Enrollment.Generate_Join_Token
                       (Public_Key => C.Get_Public_Key,
                        Config     => C.Config.Enrollment,
                        Token      => Token);
                     Set_Setting
                       (C.DB,
                        "registration_secret",
                        Ada.Strings.Unbounded.To_String
                          (C.Config.Enrollment.Secret));
                     Podmander.Logging.Info
                       ("controller",
                        "Generated and persisted registration secret");
                  end;
               else
                  raise;
               end if;
         end;

         CZMQ.Sockets.Open_Router (C.Socket);
         C.Certificate.Apply (C.Socket);
         C.Socket.Set_Curve_Server (True);
         C.Socket.Bind (Get_Bind_Address (Config));
         Podmander.Logging.Info
           ("controller", "Listening on " & Get_Bind_Address (Config));
      end return;
   end Make_Listening_Controller;

   procedure Handle_Message (Self : in out Controller_Instance) is
      Msg    : CZMQ.Messages.Message;
      Status : CZMQ.Messages.Receive_Status;

      -- Safe: Handler is stack-local to Handle_Message and cannot outlive
      -- Self. Unchecked_Access avoids aliasing-aspect declarations here.
      Handler : Message_Handlers.Controller_Handler :=
        (Ctrl => Self'Unchecked_Access, Identity => Null_Unbounded_String);
   begin
      CZMQ.Messages.Receive (Self.Socket, Msg, Status);
      if Status = CZMQ.Messages.Timeout then
         return;
      end if;

      Handler.Identity := To_Unbounded_String (Msg.Pop_String);
      declare
         Decoded : constant Podmander.Messages.Protocol_Message'Class :=
           Podmander.Messages.Decode (Msg);
      begin
         Decoded.Dispatch_To (Handler);
      exception
         when Podmander.Messages.Decode_Error =>
            Podmander.Logging.Warning
              ("controller",
               "Malformed message from " & To_String (Handler.Identity));
      end;
   end Handle_Message;

   procedure Check_Timeouts (Self : in out Controller_Instance) is
      use type Ada.Calendar.Time;
      Now                    : constant Ada.Calendar.Time :=
        Ada.Calendar.Clock;
      Unresponsive_Threshold : constant Duration :=
        Self.Config.Agent_Timeout * 2.0;
      Lost_Threshold         : constant Duration :=
        Self.Config.Agent_Timeout * 3.0;
      All_Agents             : constant Podmander.Types.Agent_Maps.Map :=
        Agent.Repository.Load_All (Self.DB);
   begin
      for Cursor in All_Agents.Iterate loop
         declare
            Info    : Podmander.Types.Agent_Info :=
              Podmander.Types.Agent_Maps.Element (Cursor);
            Name    : constant String := To_String (Info.Name);
            Elapsed : constant Duration := Now - Info.Last_Seen;
         begin
            if Elapsed >= Lost_Threshold
              and then Info.State /= Podmander.Types.Lost
            then
               Info.State := Podmander.Types.Lost;
               Agent.Repository.Set_State (Self.DB, Info);
               Podmander.Logging.Warning
                 ("controller", "Agent " & Name & " disconnected");
            elsif Elapsed >= Unresponsive_Threshold
              and then Info.State = Podmander.Types.Registered
            then
               Info.State := Podmander.Types.Unresponsive;
               Agent.Repository.Set_State (Self.DB, Info);
               Podmander.Logging.Warning
                 ("controller", "Agent " & Name & " unresponsive");
            end if;
         end;
      end loop;
   end Check_Timeouts;

   procedure Run (Self : in out Controller_Instance) is
      Poller : CZMQ.Pollers.Poller;
   begin
      CZMQ.Pollers.Open (Poller, Self.Socket);
      while Self.Running and then not CZMQ.Signals.Is_Interrupted loop
         if Poller.Wait (Poll_Interval_Ms) then
            Handle_Message (Self);
         end if;
         Check_Timeouts (Self);
         Reconcile_State (Self);
      end loop;
      CZMQ.Pollers.Close (Poller);
   end Run;

   function To_Service_Definition
     (SV : Service_Version; Name : String) return Service_Definition is
   begin
      return
        (Name          => To_Unbounded_String (Name),
         Image         => SV.Image,
         Env           => SV.Env,
         Env_Count     => SV.Env_Count,
         Ports         => SV.Ports,
         Ports_Count   => SV.Ports_Count,
         Volumes       => SV.Volumes,
         Volumes_Count => SV.Volumes_Count,
         Description   => SV.Description,
         WantedBy      => SV.Wanted_By);
   end To_Service_Definition;

   procedure Reconcile_State (Self : in out Controller_Instance) is
      use Podmander.Controller.Service_Catalog.Repository;
      use Podmander.Messages.Deploy_Commands;

      -- Step 1: Schedule unscheduled entries
      Unscheduled : constant Catalog_Entry_Vectors.Vector :=
        Get_Unscheduled (Self.DB);
   begin
      for Cursor in Unscheduled.Iterate loop
         declare
            Cat_Entry : constant Service_Catalog_Entry :=
              Catalog_Entry_Vectors.Element (Cursor);
            Result    : constant Scheduler.Schedule_Result :=
              Scheduler.Schedule
                (Self.DB, Cat_Entry.Service_Id, Cat_Entry.Target_Version);
         begin
          if Result.Ok then
                if Result.Catalog_Entry.Agent_Id /= 0 then
                   Podmander.Logging.Info
                     ("controller",
                      "Scheduled catalog entry "
                      & Cat_Entry.Id'Image
                      & " to agent "
                      & Result.Catalog_Entry.Agent_Id'Image);
                end if;
            end if;
         -- If no agents connected, leave unscheduled and try next iteration
         end;
      end loop;

      -- Step 2: Deploy drifted entries
      declare
         Drift : constant Catalog_Entry_Vectors.Vector := Get_Drift (Self.DB);
      begin
         for Cursor in Drift.Iterate loop
             declare
                Cat_Entry : constant Service_Catalog_Entry :=
                  Catalog_Entry_Vectors.Element (Cursor);
             begin
                -- Skip entries without an agent assigned (shouldn't happen
                -- after step 1, but guard against race conditions)
                if Cat_Entry.Agent_Id = 0 then
                   goto Continue;
                end if;

                --  Only deploy to agents that are currently connected.
                declare
                   All_Agents    : constant Podmander.Types.Agent_Maps.Map :=
                     Agent.Repository.Load_All (Self.DB);
                   Agent_Found   : Boolean := False;
                   Agent_Node_Id : Ada.Strings.Unbounded.Unbounded_String;
                begin
                   for Cur in All_Agents.Iterate loop
                      declare
                         Info : constant Podmander.Types.Agent_Info :=
                           Podmander.Types.Agent_Maps.Element (Cur);
                      begin
                         if Info.Id = Integer (Cat_Entry.Agent_Id)
                           and then Info.State = Podmander.Types.Registered
                         then
                            Agent_Found := True;
                            Agent_Node_Id := Info.Node_Id;
                            exit;
                         end if;
                      end;
                   end loop;
                   if not Agent_Found then
                      goto Continue;
                   end if;

                   -- Look up the service version to get the ASD
                   declare
                      SV           : constant Service_Version :=
                        Service.Repository.Get_Version
                          (Self.DB,
                           Cat_Entry.Service_Id,
                           Cat_Entry.Target_Version);
                      SD           : constant Service_Definition :=
                        To_Service_Definition (SV, "");
                      Svc          :
                        constant Podmander.Controller.Service.Service :=
                          Service.Repository.Get_By_Id
                            (Self.DB, Cat_Entry.Service_Id);
                      SD_With_Name : constant Service_Definition :=
                        (Name          => Svc.Name,
                         Image         => SD.Image,
                         Env           => SD.Env,
                         Env_Count     => SD.Env_Count,
                         Ports         => SD.Ports,
                         Ports_Count   => SD.Ports_Count,
                         Volumes       => SD.Volumes,
                         Volumes_Count => SD.Volumes_Count,
                         Description   => SD.Description,
                         WantedBy      => SD.WantedBy);
                      Quadlet      : constant String :=
                        Podmander.Generators.Quadlet.Render (SD_With_Name);
                      Cmd          : constant Deploy_Command :=
                        (Catalog_Id   => Cat_Entry.Id,
                         Service_Name => Svc.Name,
                         Quadlet      => To_Unbounded_String (Quadlet));
                      Msg          : CZMQ.Messages.Message :=
                        CZMQ.Messages.New_Message;
                   begin
                      Msg.Add_String (To_String (Agent_Node_Id));
                      Cmd.Encode (Msg);
                      Msg.Send (Self.Socket);
                      declare
                         Set_State_Ok : constant Boolean :=
                           Set_State (Self.DB, Cat_Entry.Id, In_Progress);
                         pragma Unreferenced (Set_State_Ok);
                      begin
                         null;
                      end;
                      Podmander.Logging.Info
                        ("controller",
                         "Deploying "
                         & To_String (Svc.Name)
                         & " v"
                         & Cat_Entry.Target_Version'Image
                         & " to "
                         & To_String (Agent_Node_Id)
                         & " (catalog "
                         & Cat_Entry.Id'Image
                         & ")");
                   end;
                end;
                <<Continue>>
             end;
         end loop;
      end;
   end Reconcile_State;

   procedure Stop (Self : in out Controller_Instance) is
   begin
      Self.Running := False;
   end Stop;

   function Get_Public_Key (Self : Controller_Instance) return String is
   begin
      if Self.Certificate.Is_Valid then
         return Self.Certificate.Public_Key;
      else
         return "";
      end if;
   end Get_Public_Key;

   procedure Generate_Join_Token
     (Self  : in out Controller_Instance;
      Token : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Podmander.Enrollment.Generate_Join_Token
        (Public_Key => Self.Get_Public_Key,
         Config     => Self.Config.Enrollment,
         Token      => Token);
   end Generate_Join_Token;

   function Load_Test_Deploy
     (Self : in out Controller_Instance; Path : String) return Boolean
   is
      Result : constant Podmander.Config.Parser.Parse_Result :=
        Podmander.Config.Parser.Parse (Path);
   begin
      if not Result.Success then
         Podmander.Logging.Error
           ("controller",
            "Failed to parse " & Path & ": " & To_String (Result.Message));
         return False;
      end if;

      declare
         Reg_Result :
           constant Podmander.Controller.Registrar.Register_Result :=
             Podmander.Controller.Registrar.Register (Self.DB, Result.Config);
      begin
         if not Reg_Result.Ok then
            Podmander.Logging.Error
              ("controller",
               "Failed to register service " & To_String (Result.Config.Name));
            return False;
         end if;

         --  Schedule the service for deployment
         declare
            Sched_Result : constant Scheduler.Schedule_Result :=
              Scheduler.Schedule
                (Self.DB,
                 Service_Id     => Reg_Result.Version.Service_Id,
                 Target_Version => Reg_Result.Version.Version);
         begin
            if not Sched_Result.Ok then
               Podmander.Logging.Error
                 ("controller",
                  "Failed to schedule " & To_String (Result.Config.Name));
               return False;
            end if;
         end;

         Podmander.Logging.Info
           ("controller",
            "Scheduled " & To_String (Result.Config.Name) & " from " & Path);
         return True;
      end;
   end Load_Test_Deploy;

end Podmander.Controller;
