--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ.Certificates;
with CZMQ.Messages;
with CZMQ.Sockets;
with Podmander.Messages;

package Podmander.Podctl.Connection is

   Reply_Timeout_Ms : constant := 5_000;

   type Controller_Connection is limited private;

   procedure Open
     (Conn       : out Controller_Connection;
      Address    : String;
      Server_Key : String);

   procedure Close (Conn : in out Controller_Connection);

   procedure Send
     (Conn    : in out Controller_Connection;
      Payload : Podmander.Messages.Protocol_Message'Class);

   procedure Receive
     (Conn   : in out Controller_Connection;
      Msg    : out CZMQ.Messages.Message;
      Status : out CZMQ.Messages.Receive_Status);

private

   type Controller_Connection is limited record
      Cert : CZMQ.Certificates.Certificate;
      Sock : CZMQ.Sockets.Socket;
   end record;

end Podmander.Podctl.Connection;
