--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with CZMQ.Messages;
with Podmander.Logging;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Register_Requests;
with Podmander.Messages.Register_Responses;
with Podmander.Shutdown;

package body Podmander.Agent is

   use Ada.Strings.Unbounded;
   use type CZMQ.Messages.Receive_Status;

   Token_Prefix : constant String := "PTKN-";

   procedure Parse_Join_Token
     (Token      : String;
      Public_Key : out Ada.Strings.Unbounded.Unbounded_String;
      Secret     : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      if Token'Length < Token_Prefix'Length + 40 + 1 + 32 then
         raise Parse_Error with "Token too short";
      end if;

      if Token (Token'First .. Token'First + Token_Prefix'Length - 1) /=
        Token_Prefix
      then
         raise Parse_Error with "Invalid token prefix";
      end if;

      declare
         Key_Start : constant Positive :=
           Token'First + Token_Prefix'Length;
         Key_End   : constant Positive := Key_Start + 39;
         Secret_Start : constant Positive := Key_End + 2;
         Secret_End   : constant Positive := Secret_Start + 31;
      begin
         if Key_End > Token'Last or else Secret_Start > Token'Last then
            raise Parse_Error with "Token malformed";
         end if;

         Public_Key := To_Unbounded_String
           (Token (Key_Start .. Key_End));
         Secret := To_Unbounded_String
           (Token (Secret_Start .. Secret_End));
      end;
   end Parse_Join_Token;

   procedure Create_Socket (Self : in out Agent_Instance) is
      Public_Key : Ada.Strings.Unbounded.Unbounded_String;
      Secret     : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Parse_Join_Token
        (To_String (Self.Config.Join_Token), Public_Key, Secret);

      Self.Enrollment_Secret := Secret;

      Self.Certificate := new CZMQ.Certificates.Certificate'
        (CZMQ.Certificates.New_Certificate);

      Self.Socket := new CZMQ.Sockets.Socket'(CZMQ.Sockets.New_Dealer);
      Self.Certificate.Apply (Self.Socket.all);
      Self.Socket.Set_Curve_Serverkey (To_String (Public_Key));
      Self.Socket.Set_Identity (To_String (Self.Config.Agent_Name));
      Self.Socket.Connect (To_String (Self.Config.Controller_Address));
   end Create_Socket;

   procedure Send_Register (Self : in out Agent_Instance) is
      use Podmander.Messages.Register_Requests;
      Req : constant Register_Request :=
        (Agent_Name        => Self.Config.Agent_Name,
         Enrollment_Secret => Self.Enrollment_Secret);
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Req.Encode (Msg);
      Msg.Send (Self.Socket.all);
      Podmander.Logging.Debug ("agent", "Sent registration request");
   end Send_Register;

   procedure Send_Heartbeat (Self : in out Agent_Instance) is
      use Podmander.Messages.Heartbeats;
      Hb  : constant Heartbeat_Message :=
        (Agent_Id  => Self.Node_Id,
         Timestamp => Ada.Calendar.Clock);
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Hb.Encode (Msg);
      Msg.Send (Self.Socket.all);
      Podmander.Logging.Debug ("agent", "Sent heartbeat");
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

   Poll_Interval_Ms : constant := 1000;

   procedure Handle_Connected (Self : in out Agent_Instance) is
      use type Ada.Calendar.Time;
      Next_Heartbeat : constant Ada.Calendar.Time :=
        Ada.Calendar.Clock + Self.Config.Heartbeat_Interval;
   begin
      Send_Heartbeat (Self);
      --  Poll with short timeout until next heartbeat is due,
      --  checking the shutdown flag each iteration.
      Self.Socket.Set_Receive_Timeout (Poll_Interval_Ms);
      while not Podmander.Shutdown.Requested loop
         declare
            Msg    : CZMQ.Messages.Message;
            Status : CZMQ.Messages.Receive_Status;
         begin
            CZMQ.Messages.Receive (Self.Socket.all, Msg, Status);
            --  Future: process controller commands on Success
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

   procedure Initialize
     (Self   : in out Agent_Instance;
      Config : Agent_Config) is
   begin
      Self.Config := Config;
      Self.Running := True;
      Podmander.Logging.Info
        ("agent", "Agent """ & To_String (Config.Agent_Name)
         & """ starting, controller at "
         & To_String (Config.Controller_Address));
   end Initialize;

   procedure Run_Once (Self : in out Agent_Instance) is
   begin
      case Self.State is
         when Podmander.Types.Disconnected =>
            Handle_Disconnected (Self);
         when Podmander.Types.Enrolling =>
            Handle_Enrolling (Self);
         when Podmander.Types.Connected =>
            Handle_Connected (Self);
      end case;
   end Run_Once;

   procedure Run (Self : in out Agent_Instance) is
   begin
      while Self.Running
        and then not Podmander.Shutdown.Requested
      loop
         Self.Run_Once;
      end loop;
   end Run;

   procedure Stop (Self : in out Agent_Instance) is
   begin
      Self.Running := False;
   end Stop;

   function Get_Server_Public_Key
     (Self : Agent_Instance) return String is
   begin
      if Self.Config.Join_Token /= Null_Unbounded_String then
         declare
            Public_Key : Ada.Strings.Unbounded.Unbounded_String;
            Secret     : Ada.Strings.Unbounded.Unbounded_String;
         begin
            Parse_Join_Token
              (To_String (Self.Config.Join_Token), Public_Key, Secret);
            return To_String (Public_Key);
         end;
      else
         return "";
      end if;
   end Get_Server_Public_Key;

end Podmander.Agent;
