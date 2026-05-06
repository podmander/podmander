--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ.Messages;

package Podmander.Messages is

   pragma Elaborate_Body;
   --  Force the body to elaborate immediately after this spec so child
   --  packages can safely call Register during their own elaboration.

   Decode_Error       : exception;
   Already_Registered : exception;

   --  Message kind discriminator strings used as the first frame
   Register_Kind   : constant String := "register";
   Registered_Kind : constant String := "registered";
   Heartbeat_Kind  : constant String := "heartbeat";
   Deploy_Kind     : constant String := "deploy";
   Deploy_Ack_Kind : constant String := "deploy_ack";

   --  Base interface for all protocol messages
   type Protocol_Message is interface;

   --  Forward declaration so Dispatch_To can reference Message_Handler.
   type Message_Handler is limited interface;

   procedure Encode
     (Self : Protocol_Message;
      Msg  : in out CZMQ.Messages.Message) is abstract;

   --  Route this message to the matching Handle_* method on a handler.
   --  Each concrete message's override is a single-line routing call;
   --  the message itself never contains handling logic.
   procedure Dispatch_To
     (Self : Protocol_Message;
      H    : in out Message_Handler'Class) is abstract;

   --  Abstract type anchors. Concrete message types live in child packages
   --  (Podmander.Messages.Register_Requests, .Register_Responses,
   --  .Heartbeats) and derive from these. Anchors exist so Message_Handler
   --  primitives can name each message category without depending on any
   --  child package, keeping the parent closed.
   type Register_Request_Type is abstract new Protocol_Message
     with null record;
   type Register_Response_Type is abstract new Protocol_Message
     with null record;
   type Heartbeat_Message_Type is abstract new Protocol_Message
     with null record;
   type Deploy_Command_Type is abstract new Protocol_Message
     with null record;
   type Deploy_Result_Type is abstract new Protocol_Message
     with null record;

   --  Handler contract for inbound messages. Adding a new message category
   --  adds a new abstract anchor above and a new primitive here; the
   --  compiler then forces every Message_Handler implementation to provide
   --  a body. This interface is the single manifest of known operations.
   procedure Handle_Register_Request
     (H : in out Message_Handler;
      M : Register_Request_Type'Class) is abstract;

   procedure Handle_Heartbeat
     (H : in out Message_Handler;
      M : Heartbeat_Message_Type'Class) is abstract;

   procedure Handle_Deploy_Command
     (H : in out Message_Handler;
      M : Deploy_Command_Type'Class) is abstract;

   procedure Handle_Deploy_Result
     (H : in out Message_Handler;
      M : Deploy_Result_Type'Class) is abstract;

   --  Decoder registry: each concrete message type registers a decoder
   --  keyed by its kind string at child-package elaboration.
   type Decoder_Access is access function
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class;

   procedure Register
     (Kind    : String;
      Decoder : Decoder_Access);

   --  Decode a CZMQ message into the appropriate protocol message.
   --  Raises Decode_Error if the message is malformed or the kind is not
   --  registered.
   function Decode
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class;

end Podmander.Messages;
