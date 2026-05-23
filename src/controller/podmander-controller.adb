--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with CZMQ.Messages;
with CZMQ.Pollers;
with Podmander.Config.Parser;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Message_Handlers;
with Podmander.Controller.Actual_State.Repository;
with Podmander.Controller.Service.Repository;
with Podmander.Generators.Quadlet;
with Podmander.Logging;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Deploy_Commands;
with CZMQ.Signals;

package body Podmander.Controller is

   use Ada.Strings.Unbounded;
   use type CZMQ.Messages.Receive_Status;
   use type Podmander.Database.Error_Kind;

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
             Running     => True,
             Test_Deploy => <>)
      do
          --  Per ADR-0037: agents that were Registered or Unresponsive
          --  start as Unresponsive â they must send a heartbeat to prove
          --  they're still alive after the controller restart.
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

         --  Load or generate CURVE certificate
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

         --  Load or generate registration secret
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
                  --  First start: generate and persist a new secret
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

      --  Safe: Handler is stack-local to Handle_Message and cannot outlive
      --  Self. Unchecked_Access avoids aliasing-aspect declarations here.
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
      All_Agents            : constant Podmander.Types.Agent_Maps.Map :=
        Agent.Repository.Load_All (Self.DB);
   begin
      for Cursor in All_Agents.Iterate loop
         declare
            Info    : Podmander.Types.Agent_Info :=
              Podmander.Types.Agent_Maps.Element (Cursor);
            Name    : constant String :=
              To_String (Info.Name);
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
         Check_Test_Deploy (Self);
      end loop;
      CZMQ.Pollers.Close (Poller);
   end Run;

   function To_Service_Definition
     (SV : Service_Version) return Service_Definition
   is
   begin
      return
        (Name          => SV.Service_Name,
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
      Mismatches : constant State_Mismatch_Vectors.Vector :=
        Find_State_Mismatches (Self.DB);
   begin
      for M of Mismatches loop
         declare
            Node_Id_Str  : constant String := To_String (M.Node_Id);
            Svc_Name_Str : constant String := To_String (M.Service_Name);
            All_Agents   : constant Podmander.Types.Agent_Maps.Map :=
              Agent.Repository.Load_All (Self.DB);
            Found        : Boolean := False;
         begin
            for Cursor in All_Agents.Iterate loop
               if To_String (Podmander.Types.Agent_Maps.Element (Cursor).Node_Id)
                 = Node_Id_Str
               then
                  Found := True;
                  exit;
               end if;
            end loop;

            if Found then
               declare
                  SV     : constant Service_Version :=
                    Service.Repository.Get_Latest_Version
                      (Self.DB, Svc_Name_Str);
                  Config : constant Service_Definition :=
                    To_Service_Definition (SV);
                  Quadlet : constant String :=
                    Podmander.Generators.Quadlet.Render (Config);
               begin
                  Self.Send_Deploy_Command
                    (Node_Id      => Node_Id_Str,
                     Service_Name => Svc_Name_Str,
                     Quadlet      => Quadlet);
               end;
            end if;
         end;
      end loop;
   end Reconcile_State;

   procedure Check_Test_Deploy (Self : in out Controller_Instance) is
   begin
      --  No pending deploy
      if Self.Test_Deploy.Service_Name = Null_Unbounded_String then
         return;
      end if;

      --  Already sent
      if Self.Test_Deploy.Deployed then
         return;
      end if;

      --  Count agents that are actually connected (Registered state).
      --  Agents loaded from the DB start as Unresponsive - they must
      --  send a heartbeat before they're considered connected.
      declare
         Registered_Count : Natural := 0;
         Target_Node_Id   : Unbounded_String := Null_Unbounded_String;
         All_Agents       : constant Podmander.Types.Agent_Maps.Map :=
           Agent.Repository.Load_All (Self.DB);
      begin
         for Cursor in All_Agents.Iterate loop
            declare
               Info : constant Podmander.Types.Agent_Info :=
                 Podmander.Types.Agent_Maps.Element (Cursor);
            begin
               if Info.State = Podmander.Types.Registered then
                  Registered_Count := Registered_Count + 1;
                  Target_Node_Id := Info.Node_Id;
               end if;
            end;
         end loop;

         if Registered_Count = 0 then
            --  No agents connected yet, keep waiting
            return;
         end if;

         if Registered_Count > 1 then
            --  --test-config targets a single agent. With multiple agents
            --  connected, we cannot select a target, so stop with an error.
            --  The production path (podctl deploy) handles multi-node deploys.
            Podmander.Logging.Error
              ("controller",
               "Multiple agents connected; cannot select target"
               & " for --test-config."
               & " Use podctl deploy for multi-node deploys.");
            Self.Test_Deploy.Deployed := True;
            Self.Stop;
            return;
         end if;

         --  Exactly one Registered agent: send the deploy command
         Self.Send_Deploy_Command
           (Node_Id      => To_String (Target_Node_Id),
            Service_Name => To_String (Self.Test_Deploy.Service_Name),
            Quadlet      => To_String (Self.Test_Deploy.Quadlet));
         Self.Test_Deploy.Deployed := True;
      end;
   end Check_Test_Deploy;

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
         Quadlet_Content : constant String :=
           Podmander.Generators.Quadlet.Render (Result.Config);
      begin
         Self.Test_Deploy :=
           (Service_Name => Result.Config.Name,
            Quadlet      => To_Unbounded_String (Quadlet_Content),
            Deployed     => False);
         Podmander.Logging.Info
           ("controller",
            "Will deploy " & To_String (Result.Config.Name) & " from " & Path);
         return True;
      end;
   end Load_Test_Deploy;

   function Find_State_Mismatches
     (DB : in out Database.DB_Handle) return State_Mismatch_Vectors.Vector
   is
      Actual : Actual_State_Vectors.Vector :=
        Actual_State.Repository.Get_All (DB);
      Result : State_Mismatch_Vectors.Vector;
   begin
      for E of Actual loop
         declare
            Svc_Name : constant String :=
              To_String (E.Service_Name);
         begin
            declare
               Latest : constant Service_Version :=
                 Service.Repository.Get_Latest_Version (DB, Svc_Name);
            begin
               if E.Version < Latest.Version then
                  Result.Append
                    (State_Mismatch'
                       (Service_Name    => E.Service_Name,
                        Node_Id         => E.Node_Id,
                        Desired_Version => Latest.Version,
                        Current_Version => E.Version));
               end if;
            end;
         exception
            when Podmander.Database.Database_Error =>
               null;
         end;
      end loop;
      return Result;
   end Find_State_Mismatches;

   procedure Send_Deploy_Command
     (Self         : in out Controller_Instance;
      Node_Id      : String;
      Service_Name : String;
      Quadlet      : String)
   is
      use Podmander.Messages.Deploy_Commands;
      Cmd : constant Deploy_Command :=
        (Service_Name => To_Unbounded_String (Service_Name),
         Quadlet      => To_Unbounded_String (Quadlet));
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      if not Self.Socket.Is_Valid then
         Podmander.Logging.Warning
           ("controller", "Cannot send deploy command: socket not open");
         return;
      end if;

      Msg.Add_String (Node_Id);
      Cmd.Encode (Msg);
      Msg.Send (Self.Socket);
      Podmander.Logging.Info
        ("controller",
         "Sent deploy command for " & Service_Name & " to " & Node_Id);
   end Send_Deploy_Command;

end Podmander.Controller;
