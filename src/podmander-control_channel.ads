--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  The Control Channel owns the controller's ZeroMQ ROUTER socket behind two
--  domain operations: send a protocol message to a connection identity, and
--  receive-and-decode the next inbound message.

with Ada.Containers.Indefinite_Holders;
with Ada.Strings.Unbounded;
with Ada.Tags;
with CZMQ.Certificates;
with CZMQ.Sockets;
with Podmander.Messages;

package Podmander.Control_Channel is

   function Same_Message_Tag
     (Left, Right : Podmander.Messages.Protocol_Message'Class) return Boolean
   is (Ada.Tags."=" (Left'Tag, Right'Tag));

   package Message_Holders is new
     Ada.Containers.Indefinite_Holders
       (Element_Type => Podmander.Messages.Protocol_Message'Class,
        "="          => Same_Message_Tag);

   type Channel is tagged limited private;

   Invalid_Certificate : exception;

   function Is_Interrupted return Boolean;
   --  Report whether CZMQ's signal handler has observed SIGINT/SIGTERM.

   procedure Listen
     (Self        : in out Channel;
      Address     : String;
      Certificate : CZMQ.Certificates.Certificate);

   procedure Close (Self : in out Channel);

   procedure Send
     (Self     : in out Channel;
      Identity : String;
      Message  : Podmander.Messages.Protocol_Message'Class);

   type Receive_Outcome is (Message_Received, No_Message, Malformed);

   procedure Receive
     (Self     : in out Channel;
      Identity : out Ada.Strings.Unbounded.Unbounded_String;
      Message  : out Message_Holders.Holder;
      Outcome  : out Receive_Outcome);

private

   type Channel is tagged limited record
      Socket : CZMQ.Sockets.Socket;
   end record;

end Podmander.Control_Channel;
