--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

package body Podmander.Podctl.Connection is

   procedure Open
     (Conn       : out Controller_Connection;
      Address    : String;
      Server_Key : String)
   is
   begin
      CZMQ.Certificates.Generate (Conn.Cert);
      CZMQ.Sockets.Open_Dealer (Conn.Sock);
      Conn.Cert.Apply (Conn.Sock);
      Conn.Sock.Set_Curve_Serverkey (Server_Key);
      Conn.Sock.Set_Identity ("podctl");
      Conn.Sock.Connect (Address);
      Conn.Sock.Set_Receive_Timeout (Reply_Timeout_Ms);
   end Open;

   procedure Close (Conn : in out Controller_Connection) is
   begin
      CZMQ.Sockets.Close (Conn.Sock);
      CZMQ.Certificates.Close (Conn.Cert);
   end Close;

   procedure Send
     (Conn    : in out Controller_Connection;
      Payload : Podmander.Messages.Protocol_Message'Class)
   is
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Payload.Encode (Msg);
      Msg.Send (Conn.Sock);
   end Send;

   procedure Receive
     (Conn   : in out Controller_Connection;
      Msg    : out CZMQ.Messages.Message;
      Status : out CZMQ.Messages.Receive_Status)
   is
   begin
      CZMQ.Messages.Receive (Conn.Sock, Msg, Status);
   end Receive;

end Podmander.Podctl.Connection;
