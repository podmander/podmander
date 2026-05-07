--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with CZMQ.Messages;
with Podmander.Agent.Message_Handlers;
with Podmander.Logging;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Register_Requests;
with Podmander.Messages.Register_Responses;
with Podmander.Shutdown;

package body Podmander.Agent.Connection is

   use Ada.Strings.Unbounded;
   use type CZMQ.Messages.Receive_Status;

   Poll_Interval_Ms : constant := 1000;

   procedure Create_Socket (Self : in out Agent_Instance) is
   begin
      Self.Certificate := new CZMQ.Certificates.Certificate'
        (CZMQ.Certificates.New_Certificate);

      Self.Socket := new CZMQ.Sockets.Socket'(CZMQ.Sockets.New_Dealer);
      Self.Certificate.Apply (Self.Socket.all);
      Self.Socket.Set_Curve_Serverkey (To_String (Self.Server_Public_Key));
      Self.Socket.Set_Identity (To_String (Self.Config.Agent_Name));
      Self.Socket.Connect (To_String (Self.Config.Controller_Address));
   end Create_Socket;

   procedure Send_Message
     (Self     : in out Agent_Instance;
      Payload  : Podmander.Messages.Protocol_Message'Class;
      Log_Text : String)
   is
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Payload.Encode (Msg);
      Msg.Send (Self.Socket.all);
      Podmander.Logging.Debug ("agent", Log_Text);
   end Send_Message;

   procedure Send_Register (Self : in out Agent_Instance) is
      use Podmander.Messages.Register_Requests;
   begin
      Send_Message
        (Self,
         Register_Request'
           (Agent_Name        => Self.Config.Agent_Name,
            Enrollment_Secret => Self.Enrollment_Secret),
         "Sent registration request");
   end Send_Register;

   procedure Send_Heartbeat (Self : in out Agent_Instance) is
      use Podmander.Messages.Heartbeats;
   begin
      Send_Message
        (Self,
         Heartbeat_Message'
           (Agent_Id  => Self.Node_Id,
            Timestamp => Ada.Calendar.Clock),
         "Sent heartbeat");
   end Send_Heartbeat;

   procedure Handle_Disconnected (Self : in out Agent_Instance) is
   begin
      Podmander.Logging.Info ("agent", "Connecting to controller...");
      Create_Socket (Self);
      Self.Socket.Set_Receive_Timeout
        (Integer (Self.Config.Registration_Timeout * 1000.0));
      Send_Register (Self);
      Self.State := Podmander.Types.Enrolling;
   end Handle_Disconnected;

   procedure Handle_Enrolling (Self : in out Agent_Instance) is
      Msg    : CZMQ.Messages.Message;
      Status : CZMQ.Messages.Receive_Status;
   begin
      CZMQ.Messages.Receive (Self.Socket.all, Msg, Status);

      if Status = CZMQ.Messages.Timeout then
         Podmander.Logging.Warning
           ("agent", "Registration timeout, retrying in"
            & Duration'Image (Self.Backoff) & "s");
         Self.Socket := null;
         delay Self.Backoff;
         Self.Backoff := Duration'Min
           (Self.Backoff * 2.0, Self.Config.Max_Backoff);
         Self.State := Podmander.Types.Disconnected;
         return;
      end if;

      declare
         use Podmander.Messages;
         use Podmander.Messages.Register_Responses;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         if Decoded in Register_Response then
            Self.Node_Id := Register_Response (Decoded).Node_Id;
            Self.State := Podmander.Types.Connected;
            Self.Backoff := 1.0;
            Podmander.Logging.Info
              ("agent", "Registered as " & To_String (Self.Node_Id));
         else
            Podmander.Logging.Warning
              ("agent", "Unexpected response during enrollment");
         end if;
      end;
   exception
      when Podmander.Messages.Decode_Error =>
         Podmander.Logging.Warning
           ("agent", "Malformed response during enrollment");
         Self.Socket := null;
         Self.State := Podmander.Types.Disconnected;
   end Handle_Enrolling;

   procedure Handle_Connected (Self : in out Agent_Instance) is
      use type Ada.Calendar.Time;
      Next_Heartbeat : constant Ada.Calendar.Time :=
        Ada.Calendar.Clock + Self.Config.Heartbeat_Interval;
      Handler : Message_Handlers.Agent_Handler :=
        (Agt => Self'Unchecked_Access);
   begin
      Send_Heartbeat (Self);
      Self.Socket.Set_Receive_Timeout (Poll_Interval_Ms);
      while not Podmander.Shutdown.Requested loop
         declare
            Msg    : CZMQ.Messages.Message;
            Status : CZMQ.Messages.Receive_Status;
         begin
            CZMQ.Messages.Receive (Self.Socket.all, Msg, Status);
            if Status /= CZMQ.Messages.Timeout then
               declare
                  Decoded : constant
                    Podmander.Messages.Protocol_Message'Class :=
                    Podmander.Messages.Decode (Msg);
               begin
                  Decoded.Dispatch_To (Handler);
               exception
                  when Podmander.Messages.Decode_Error =>
                     Podmander.Logging.Warning
                       ("agent", "Malformed message from controller");
               end;
            end if;
         end;
         exit when Ada.Calendar.Clock >= Next_Heartbeat;
      end loop;
   exception
      when CZMQ.CZMQ_Error =>
         Podmander.Logging.Warning
           ("agent", "Connection lost, reconnecting...");
         Self.Socket := null;
         Self.State := Podmander.Types.Disconnected;
   end Handle_Connected;

   procedure Step (Self : in out Agent_Instance) is
   begin
      case Self.State is
         when Podmander.Types.Disconnected =>
            Handle_Disconnected (Self);
         when Podmander.Types.Enrolling =>
            Handle_Enrolling (Self);
         when Podmander.Types.Connected =>
            Handle_Connected (Self);
      end case;
   end Step;

end Podmander.Agent.Connection;
