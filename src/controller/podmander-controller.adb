--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with CZMQ.Messages;
with Podmander.Controller.Message_Handlers;
with Podmander.Logging;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Shutdown;

package body Podmander.Controller is

   use Ada.Strings.Unbounded;
   use type CZMQ.Messages.Receive_Status;

   procedure Set_Bind_Address
     (Config  : in out Controller_Config;
      Address : String) is
   begin
      Config.Bind_Address (1 .. Address'Length) := Address;
      Config.Bind_Address_Last := Address'Length;
   end Set_Bind_Address;

   function Get_Bind_Address (Config : Controller_Config) return String is
   begin
      return Config.Bind_Address (1 .. Config.Bind_Address_Last);
   end Get_Bind_Address;

   procedure Initialize
      (Self   : in out Controller_Instance;
       Config : Controller_Config) is
   begin
      Self.Config := Config;
      Self.Certificate := new CZMQ.Certificates.Certificate'
        (CZMQ.Certificates.New_Certificate);
      Self.Socket := new CZMQ.Sockets.Socket'(CZMQ.Sockets.New_Router);
      Self.Certificate.Apply (Self.Socket.all);
      Self.Socket.Set_Curve_Server (True);
      Self.Socket.Bind (Get_Bind_Address (Config));
      Self.Poller :=
        new CZMQ.Pollers.Poller'
          (CZMQ.Pollers.New_Poller (Self.Socket.all));
      Self.Running := True;
      Podmander.Logging.Info
        ("controller", "Listening on " & Get_Bind_Address (Config));
   end Initialize;

   procedure Handle_Message (Self : in out Controller_Instance) is
      Msg    : CZMQ.Messages.Message;
      Status : CZMQ.Messages.Receive_Status;

      --  Safe: Handler is stack-local to Handle_Message and cannot outlive
      --  Self. Unchecked_Access avoids aliasing-aspect declarations here.
      Handler : Message_Handlers.Controller_Handler :=
        (Ctrl     => Self'Unchecked_Access,
         Identity => Null_Unbounded_String);
   begin
      CZMQ.Messages.Receive (Self.Socket.all, Msg, Status);
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
              ("controller", "Malformed message from "
               & To_String (Handler.Identity));
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
   begin
      for Cursor in Self.Agents.Iterate loop
         declare
            Key     : constant String := Agent_Maps.Key (Cursor);
            Info    : Podmander.Types.Agent_Info :=
              Agent_Maps.Element (Cursor);
            Elapsed : constant Duration := Now - Info.Last_Seen;
         begin
            if Elapsed >= Lost_Threshold
              and then Info.State /= Podmander.Types.Lost
            then
               Info.State := Podmander.Types.Lost;
               Self.Agents.Replace (Key, Info);
               Podmander.Logging.Warning
                 ("controller", "Agent " & Key & " disconnected");
            elsif Elapsed >= Unresponsive_Threshold
              and then Info.State = Podmander.Types.Registered
            then
               Info.State := Podmander.Types.Unresponsive;
               Self.Agents.Replace (Key, Info);
               Podmander.Logging.Warning
                 ("controller", "Agent " & Key & " unresponsive");
            end if;
         end;
      end loop;
   end Check_Timeouts;

   Poll_Interval_Ms : constant := 1000;

   procedure Run_Once (Self : in out Controller_Instance) is
   begin
      if Self.Poller.Wait (Poll_Interval_Ms) then
         Handle_Message (Self);
      end if;
      Check_Timeouts (Self);
   end Run_Once;

   procedure Run (Self : in out Controller_Instance) is
   begin
      while Self.Running
        and then not Podmander.Shutdown.Requested
      loop
         Self.Run_Once;
      end loop;
   end Run;

   procedure Stop (Self : in out Controller_Instance) is
   begin
      Self.Running := False;
   end Stop;

   function Get_Public_Key (Self : Controller_Instance) return String is
   begin
      if Self.Certificate /= null then
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

end Podmander.Controller;
