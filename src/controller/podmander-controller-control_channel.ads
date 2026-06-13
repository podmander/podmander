--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  The Control Channel wraps the controller's ZeroMQ ROUTER socket behind two
--  domain operations: send a protocol message to a connection identity, and
--  receive-and-decode the next inbound message. It borrows the socket from the
--  composition root (the controller keeps ownership) and confines every CZMQ
--  call to its body, so domain collaborators -- the Supervisor and the message
--  handlers -- never name a CZMQ type. Send is a no-op while the borrowed
--  socket is not open, which is the seam that lets handler logic run in tests
--  without a live socket.

with Ada.Containers.Indefinite_Holders;
with Ada.Strings.Unbounded;
with Ada.Tags;
with CZMQ.Sockets;
with Podmander.Messages;

package Podmander.Controller.Control_Channel is

   function Same_Message_Tag
     (Left, Right : Podmander.Messages.Protocol_Message'Class) return Boolean
   is (Ada.Tags."=" (Left'Tag, Right'Tag));
   --  Holder equality is never exercised by this package, but Indefinite_Holders
   --  needs a total "=" to instantiate. Protocol_Message is an abstract
   --  interface, so its class-wide predefined "=" is abstract and cannot serve;
   --  tag identity is a safe, total stand-in.

   package Message_Holders is new
     Ada.Containers.Indefinite_Holders
       (Element_Type => Podmander.Messages.Protocol_Message'Class,
        "="          => Same_Message_Tag);
   --  Carries a decoded message out of Receive. The element is a domain type,
   --  so no CZMQ type crosses the package boundary.

   type Channel is tagged private;

   function Wrap (Socket : access CZMQ.Sockets.Socket) return Channel;
   --  Borrow an externally owned ROUTER socket. The socket may be unopened
   --  (Is_Valid = False), in which case Send no-ops.

   procedure Send
     (Self     : Channel;
      Identity : String;
      Message  : Podmander.Messages.Protocol_Message'Class);
   --  Encode Message and send it to the agent or operator identified by
   --  Identity (the ROUTER routing frame). No-op when the borrowed socket is
   --  not open. Self is mode in: the handle is unchanged, only the borrowed
   --  socket is, so a freshly wrapped socket can be sent through inline.

   type Receive_Outcome is (Message_Received, No_Message, Malformed);
   --  Message_Received: Identity and Message are both set.
   --  No_Message:       nothing was waiting (poll timeout); outputs are unset.
   --  Malformed:        a frame arrived but failed to decode; Identity is set
   --                    so the caller can report the sender, Message is empty.

   procedure Receive
     (Self     : Channel;
      Identity : out Ada.Strings.Unbounded.Unbounded_String;
      Message  : out Message_Holders.Holder;
      Outcome  : out Receive_Outcome);
   --  Receive the next inbound message: pop the routing Identity frame and
   --  decode the payload into a protocol message. Reports No_Message when the
   --  socket has nothing waiting and Malformed when decoding fails.

private

   --  An anonymous access component (as the message handler uses for its
   --  controller back-reference) lets Wrap store the borrowed socket directly,
   --  without a named-access conversion that would impose a library-level
   --  accessibility check on stack-local controllers in tests.
   type Channel is tagged record
      Socket : access CZMQ.Sockets.Socket;
   end record;

end Podmander.Controller.Control_Channel;
