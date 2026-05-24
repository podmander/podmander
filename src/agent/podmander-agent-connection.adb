--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with CZMQ.Certificates;
with CZMQ.Messages;
with CZMQ.Sockets;
with Podmander.Agent.Message_Handlers;
with Podmander.Logging;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Registration_Requests;
with Podmander.Messages.Registration_Responses;
with CZMQ.Signals;

package body Podmander.Agent.Connection is

   use Ada.Strings.Unbounded;
   use type CZMQ.Messages.Receive_Status;

   Poll_Interval_Ms : constant := 1000;

   procedure Send_Message
     (Sock     : in out CZMQ.Sockets.Socket;
      Payload  : Podmander.Messages.Protocol_Message'Class;
      Log_Text : String)
   is
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Payload.Encode (Msg);
      Msg.Send (Sock);
      Podmander.Logging.Debug ("agent", Log_Text);
   end Send_Message;

   procedure Send_Registration
     (Self : Agent_Instance; Sock : in out CZMQ.Sockets.Socket)
   is
      use Podmander.Messages.Registration_Requests;
   begin
      Send_Message
        (Sock,
         Registration_Request'
           (Agent_Name        => Self.Config.Agent_Name,
            Enrollment_Secret => Self.Enrollment_Secret),
         "Sent registration request");
   end Send_Registration;

   procedure Send_Heartbeat
     (Self : Agent_Instance; Sock : in out CZMQ.Sockets.Socket)
   is
      use Podmander.Messages.Heartbeats;
   begin
      Send_Message
        (Sock,
         Heartbeat_Message'
           (Node_Id => Self.Node_Id, Timestamp => Ada.Calendar.Clock),
         "Sent heartbeat");
   end Send_Heartbeat;

   procedure Run_Cycle (Self : in out Agent_Instance) is
   begin
      -- Close previous cycle's resources (idempotent  -- no-op if
      -- already closed or never opened).
      CZMQ.Sockets.Close (Self.Sock);
      CZMQ.Certificates.Close (Self.Certificate);

      -- Disconnected -> Enrolling: open the socket and send register.
      Podmander.Logging.Info ("agent", "Connecting to controller...");
      CZMQ.Certificates.Generate (Self.Certificate);
      CZMQ.Sockets.Open_Dealer (Self.Sock);
      Self.Certificate.Apply (Self.Sock);
      Self.Sock.Set_Curve_Serverkey (To_String (Self.Server_Public_Key));
      Self.Sock.Set_Identity (To_String (Self.Config.Agent_Name));
      Self.Sock.Connect (To_String (Self.Config.Controller_Address));
      Self.Sock.Set_Receive_Timeout
        (Integer (Self.Config.Registration_Timeout * 1000.0));

      Send_Registration (Self, Self.Sock);
      Self.State := Podmander.Types.Enrolling;

      -- Enrolling: wait for register response.
      declare
         Msg    : CZMQ.Messages.Message;
         Status : CZMQ.Messages.Receive_Status;
      begin
         CZMQ.Messages.Receive (Self.Sock, Msg, Status);

         if Status = CZMQ.Messages.Timeout then
            Podmander.Logging.Warning
              ("agent",
               "Registration timeout, retrying in"
               & Duration'Image (Self.Backoff)
               & "s");
            delay Self.Backoff;
            Self.Backoff :=
              Duration'Min (Self.Backoff * 2.0, Self.Config.Max_Backoff);
            Self.State := Podmander.Types.Disconnected;
            return;
         end if;

         declare
            use Podmander.Messages;
            use Podmander.Messages.Registration_Responses;
            Decoded : constant Protocol_Message'Class := Decode (Msg);
         begin
            if Decoded in Registration_Response then
               Self.Node_Id := Registration_Response (Decoded).Node_Id;
               Self.State := Podmander.Types.Connected;
               Self.Backoff := 1.0;
               Podmander.Logging.Info
                 ("agent", "Registered as " & To_String (Self.Node_Id));
            else
               Podmander.Logging.Warning
                 ("agent", "Unexpected response during enrollment");
               Self.State := Podmander.Types.Disconnected;
               return;
            end if;
         end;
      exception
         when Podmander.Messages.Decode_Error =>
            Podmander.Logging.Warning
              ("agent", "Malformed response during enrollment");
            Self.State := Podmander.Types.Disconnected;
            return;
      end;

      -- Connected: heartbeat-bounded receive loop until shutdown,
      -- Stop, or connection error.
      Self.Sock.Set_Receive_Timeout (Poll_Interval_Ms);
      declare
         Handler : Message_Handlers.Agent_Handler :=
           (Agt => Self'Unchecked_Access);
      begin
         while Self.Running and then not CZMQ.Signals.Is_Interrupted loop
            declare
               use type Ada.Calendar.Time;
               Next_Heartbeat : Ada.Calendar.Time;
            begin
               Send_Heartbeat (Self, Self.Sock);
               Next_Heartbeat :=
                 Ada.Calendar.Clock + Self.Config.Heartbeat_Interval;
               while not CZMQ.Signals.Is_Interrupted loop
                  declare
                     Msg    : CZMQ.Messages.Message;
                     Status : CZMQ.Messages.Receive_Status;
                  begin
                     CZMQ.Messages.Receive (Self.Sock, Msg, Status);
                     if Status /= CZMQ.Messages.Timeout then
                        declare
                           Decoded :
                             constant Podmander
                                        .Messages
                                        .Protocol_Message'Class :=
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
            end;
         end loop;
      end;
   exception
      when CZMQ.CZMQ_Error =>
         Podmander.Logging.Warning
           ("agent", "Connection lost, reconnecting...");
         Self.State := Podmander.Types.Disconnected;
   end Run_Cycle;

end Podmander.Agent.Connection;
