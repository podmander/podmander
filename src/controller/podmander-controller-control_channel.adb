--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ.Messages;

package body Podmander.Controller.Control_Channel is

   use Ada.Strings.Unbounded;
   use type CZMQ.Messages.Receive_Status;

   function Wrap (Socket : access CZMQ.Sockets.Socket) return Channel is
   begin
      return (Socket => Socket);
   end Wrap;

   procedure Send
     (Self     : Channel;
      Identity : String;
      Message  : Podmander.Messages.Protocol_Message'Class) is
   begin
      if Self.Socket = null or else not Self.Socket.Is_Valid then
         return;
      end if;

      declare
         Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
      begin
         Msg.Add_String (Identity);
         Message.Encode (Msg);
         Msg.Send (Self.Socket.all);
      end;
   end Send;

   procedure Receive
     (Self     : Channel;
      Identity : out Ada.Strings.Unbounded.Unbounded_String;
      Message  : out Message_Holders.Holder;
      Outcome  : out Receive_Outcome)
   is
      Msg    : CZMQ.Messages.Message;
      Status : CZMQ.Messages.Receive_Status;
   begin
      Identity := Null_Unbounded_String;
      Message := Message_Holders.Empty_Holder;

      if Self.Socket = null or else not Self.Socket.Is_Valid then
         Outcome := No_Message;
         return;
      end if;

      CZMQ.Messages.Receive (Self.Socket.all, Msg, Status);
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

end Podmander.Controller.Control_Channel;
