--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Environment_Variables;
with CZMQ.Signals;
with Podmander.Controller.Agent.Liveness;
with Podmander.Controller.Enrollment_Authority;
with Podmander.Controller.Message_Handlers;
with Podmander.Controller.Supervisor;
with Podmander.Logging;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);

package body Podmander.Controller is

   package EA renames Podmander.Controller.Enrollment_Authority;
   package Liveness renames Podmander.Controller.Agent.Liveness;

   use Ada.Strings.Unbounded;

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
            Channel     => <>,
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

         EA.Bootstrap_Secret (C.DB, C.Config.Enrollment);
         Podmander.Control_Channel.Listen
           (C.Channel, Get_Bind_Address (Config), C.Certificate);
         Podmander.Logging.Info
           ("controller", "Listening on " & Get_Bind_Address (Config));
      end return;
   end Make_Listening_Controller;

   procedure Handle_Message
     (Self : in out Controller_Instance;
      Chan : in out Podmander.Control_Channel.Channel)
   is
      Handler : Message_Handlers.Controller_Handler :=
        (Ctrl => Self'Unchecked_Access, Identity => Null_Unbounded_String);
      Message : Podmander.Control_Channel.Message_Holders.Holder;
      Outcome : Podmander.Control_Channel.Receive_Outcome;
   begin
      Chan.Receive (Handler.Identity, Message, Outcome);
      case Outcome is
         when Podmander.Control_Channel.No_Message       =>
            null;

         when Podmander.Control_Channel.Malformed        =>
            Podmander.Logging.Warning
              ("controller",
               "Malformed message from " & To_String (Handler.Identity));

         when Podmander.Control_Channel.Message_Received =>
            Message.Element.Dispatch_To (Handler);
      end case;
   end Handle_Message;

   procedure Run (Self : in out Controller_Instance) is
   begin
      while Self.Running and then not CZMQ.Signals.Is_Interrupted loop
         Handle_Message (Self, Self.Channel);
         exit when CZMQ.Signals.Is_Interrupted;
         Liveness.Check_Timeouts (Self.DB, Self.Config.Agent_Timeout);
         Supervisor.Tick (Self.DB, Self.Channel);
      end loop;
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
