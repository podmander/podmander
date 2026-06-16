--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ;
with CZMQ.Messages;
with CZMQ.Signals;

package body Podmander.Control_Channel is

   use Ada.Strings.Unbounded;
   use type CZMQ.Messages.Receive_Status;

   Receive_Timeout_Ms : constant := 1000;

   procedure Listen
     (Self        : in out Channel;
      Address     : String;
      Certificate : CZMQ.Certificates.Certificate) is
   begin
      if not Certificate.Is_Valid then
         raise Invalid_Certificate;
      end if;

      CZMQ.Sockets.Open_Router (Self.Socket);
      Certificate.Apply (Self.Socket);
      Self.Socket.Set_Curve_Server (True);
      Self.Socket.Set_Receive_Timeout (Receive_Timeout_Ms);
      Self.Socket.Bind (Address);
   end Listen;

   procedure Close (Self : in out Channel) is
   begin
      if Self.Socket.Is_Valid then
         Self.Socket.Close;
      end if;
   end Close;

   procedure Send
     (Self     : in out Channel;
      Identity : String;
      Message  : Podmander.Messages.Protocol_Message'Class) is
   begin
      if not Self.Socket.Is_Valid then
         return;
      end if;

      declare
         Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
      begin
         Msg.Add_String (Identity);
         Message.Encode (Msg);
         Msg.Send (Self.Socket);
      end;
   end Send;

   procedure Receive
     (Self     : in out Channel;
      Identity : out Ada.Strings.Unbounded.Unbounded_String;
      Message  : out Message_Holders.Holder;
      Outcome  : out Receive_Outcome)
   is
      Msg    : CZMQ.Messages.Message;
      Status : CZMQ.Messages.Receive_Status;
   begin
      Identity := Null_Unbounded_String;
      Message := Message_Holders.Empty_Holder;

      if not Self.Socket.Is_Valid then
         Outcome := No_Message;
         return;
      end if;

      begin
         CZMQ.Messages.Receive (Self.Socket, Msg, Status);
      exception
         when CZMQ.CZMQ_Error =>
            if CZMQ.Signals.Is_Interrupted then
               Outcome := No_Message;
               return;
            end if;
            raise;
      end;

      if Status = CZMQ.Messages.Timeout then
         Outcome := No_Message;
         return;
      end if;

      Identity := To_Unbounded_String (Msg.Pop_String);
      begin
         Message :=
           Message_Holders.To_Holder (Podmander.Messages.Decode (Msg));
         Outcome := Message_Received;
      exception
         when Podmander.Messages.Decode_Error =>
            Outcome := Malformed;
      end;
   end Receive;

end Podmander.Control_Channel;
