--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Environment_Variables;
with CZMQ.Pollers;
with Podmander.Controller.Agent.Liveness;
with Podmander.Controller.Control_Channel;
with Podmander.Controller.Enrollment_Authority;
with Podmander.Controller.Message_Handlers;
with Podmander.Controller.Supervisor;
with Podmander.Logging;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with CZMQ.Signals;

package body Podmander.Controller is

   package EA renames Podmander.Controller.Enrollment_Authority;
   package Liveness renames Podmander.Controller.Agent.Liveness;

   use Ada.Strings.Unbounded;

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
         Liveness.Recover (C.DB);
         Supervisor.Recover (C.DB);

         declare
            Cert_Path : constant String :=
              Ada.Directories.Containing_Directory (DB_Path)
              & "/controller.crt";
         begin
            EA.Bootstrap_Certificate (C.Certificate, Cert_Path);
         end;

         EA.Bootstrap_Secret
           (C.DB, EA.Get_Public_Key (C.Certificate), C.Config.Enrollment);

         CZMQ.Sockets.Open_Router (C.Socket);
         C.Certificate.Apply (C.Socket);
         C.Socket.Set_Curve_Server (True);
         C.Socket.Bind (Get_Bind_Address (Config));
         Podmander.Logging.Info
           ("controller", "Listening on " & Get_Bind_Address (Config));
      end return;
   end Make_Listening_Controller;

   procedure Handle_Message
     (Self : in out Controller_Instance; Chan : Control_Channel.Channel)
   is
      -- Safe: Handler is stack-local to Handle_Message and cannot outlive
      -- Self. Unchecked_Access avoids aliasing-aspect declarations here.
      Handler : Message_Handlers.Controller_Handler :=
        (Ctrl => Self'Unchecked_Access, Identity => Null_Unbounded_String);
      Message : Control_Channel.Message_Holders.Holder;
      Outcome : Control_Channel.Receive_Outcome;
   begin
      Chan.Receive (Handler.Identity, Message, Outcome);
      case Outcome is
         when Control_Channel.No_Message       =>
            null;

         when Control_Channel.Malformed        =>
            Podmander.Logging.Warning
              ("controller",
               "Malformed message from " & To_String (Handler.Identity));

         when Control_Channel.Message_Received =>
            Message.Element.Dispatch_To (Handler);
      end case;
   end Handle_Message;

   procedure Run (Self : in out Controller_Instance) is
      Poller : CZMQ.Pollers.Poller;
      Chan   : constant Control_Channel.Channel :=
        Control_Channel.Wrap (Self.Socket'Unchecked_Access);
   begin
      CZMQ.Pollers.Open (Poller, Self.Socket);
      while Self.Running and then not CZMQ.Signals.Is_Interrupted loop
         if Poller.Wait (Poll_Interval_Ms) then
            Handle_Message (Self, Chan);
         end if;
         Liveness.Check_Timeouts (Self.DB, Self.Config.Agent_Timeout);
         Supervisor.Tick (Self.DB, Chan);
      end loop;
      CZMQ.Pollers.Close (Poller);
   end Run;

   procedure Stop (Self : in out Controller_Instance) is
   begin
      Self.Running := False;
   end Stop;

   function Get_Public_Key (Self : Controller_Instance) return String is
   begin
      return EA.Get_Public_Key (Self.Certificate);
   end Get_Public_Key;

   procedure Generate_Join_Token
     (Self  : in out Controller_Instance;
      Token : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      EA.Generate_Join_Token (Self.Certificate, Self.Config.Enrollment, Token);
   end Generate_Join_Token;

end Podmander.Controller;
