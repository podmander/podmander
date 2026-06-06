--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ.Messages;
with GNATCOLL.JSON;

package Podmander.Messages is

   -- Child package bodies that call Register during elaboration MUST
   -- include pragma Elaborate(Podmander.Messages) to ensure the decoder
   -- registry is initialized before their begin blocks execute.

   Decode_Error       : exception;
   Already_Registered : exception;

   -- Message kind discriminator strings used as the JSON "kind" field
   Registration_Request_Kind  : constant String := "registration";
   Registration_Response_Kind : constant String := "registered";
   Heartbeat_Kind             : constant String := "heartbeat";
   Deploy_Kind                : constant String := "deploy";
   Deploy_Ack_Kind            : constant String := "deploy_ack";
   Status_Kind                : constant String := "status";
   Status_Ack_Kind            : constant String := "status_ack";
   Stack_Submission_Kind        : constant String := "stack_submission";
   Stack_Submission_Result_Kind : constant String := "stack_submission_ack";

   -- Base interface for all protocol messages
   type Protocol_Message is interface;

   -- Forward declaration so Dispatch_To can reference Message_Handler.
   type Message_Handler is limited interface;

   procedure Encode
     (Self : Protocol_Message; Msg : in out CZMQ.Messages.Message)
   is abstract;

   -- Route this message to the matching Handle_* method on a handler.
   -- Each concrete message's override is a single-line routing call;
   -- the message itself never contains handling logic.
   procedure Dispatch_To
     (Self : Protocol_Message; H : in out Message_Handler'Class)
   is abstract;

   -- Abstract type anchors. Concrete message types live in child packages
   -- (Podmander.Messages.Registration_Requests, .Registration_Responses,
   -- .Heartbeats) and derive from these. Anchors exist so Message_Handler
   -- primitives can name each message category without depending on any
   -- child package, keeping the parent closed.
   type Registration_Request_Type is abstract new Protocol_Message
   with null record;
   type Registration_Response_Type is abstract new Protocol_Message
   with null record;
   type Heartbeat_Message_Type is abstract new Protocol_Message
   with null record;
   type Deploy_Command_Type is abstract new Protocol_Message with null record;
   type Deploy_Result_Type is abstract new Protocol_Message with null record;
   type Status_Query_Type is abstract new Protocol_Message with null record;
   type Status_Response_Type is abstract new Protocol_Message with null record;
   type Stack_Submission_Type is abstract new Protocol_Message with null record;
   type Stack_Submission_Result_Type is abstract new Protocol_Message with null record;

   -- Handler contract for inbound messages. Adding a new message category
   -- adds a new abstract anchor above and a new primitive here; the
   -- compiler then forces every Message_Handler implementation to provide
   -- a body. This interface is the single manifest of known operations.
   procedure Handle_Registration_Request
     (H : in out Message_Handler; M : Registration_Request_Type'Class)
   is abstract;

   procedure Handle_Heartbeat
     (H : in out Message_Handler; M : Heartbeat_Message_Type'Class)
   is abstract;

   procedure Handle_Deploy_Command
     (H : in out Message_Handler; M : Deploy_Command_Type'Class)
   is abstract;

   procedure Handle_Deploy_Result
     (H : in out Message_Handler; M : Deploy_Result_Type'Class)
   is abstract;

   procedure Handle_Status_Query
     (H : in out Message_Handler; M : Status_Query_Type'Class)
   is abstract;

   procedure Handle_Status_Response
      (H : in out Message_Handler; M : Status_Response_Type'Class)
   is abstract;

procedure Handle_Stack_Submission
       (H : in out Message_Handler; M : Stack_Submission_Type'Class)
   is abstract;

   procedure Handle_Stack_Submission_Result
       (H : in out Message_Handler; M : Stack_Submission_Result_Type'Class)
   is abstract;

   -- Decoder registry: each concrete message type registers a decoder
   -- keyed by its kind string at child-package elaboration.
   type Decoder_Access is
     access function
       (Obj : GNATCOLL.JSON.JSON_Value) return Protocol_Message'Class;

   procedure Register (Kind : String; Decoder : Decoder_Access);

   -- Decode a CZMQ message into the appropriate protocol message.
   -- Parses the single ZMQ frame as a JSON object and routes by the
   -- "kind" field. Raises Decode_Error if the JSON is malformed or
   -- the kind is not registered.
   function Decode
     (Msg : in out CZMQ.Messages.Message) return Protocol_Message'Class;

end Podmander.Messages;
