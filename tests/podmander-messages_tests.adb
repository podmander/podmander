--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with CZMQ.Messages;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Register_Requests;
with Podmander.Messages.Register_Responses;

package body Podmander.Messages_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   type Message_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Message_Test) return AUnit.Message_String is
     (AUnit.Format ("Message Protocol"));

   overriding procedure Register_Tests (T : in out Message_Test);

   --  Test: Register_Request round-trip encode/decode
   procedure Test_Register_Request_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Register_Requests;
      Original : constant Register_Request :=
        (Agent_Name => To_Unbounded_String ("web-1"));
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 2, "Expected 2 frames, got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert
           (Decoded in Register_Request,
            "Expected Register_Request");
         Assert
           (To_String (Register_Request (Decoded).Agent_Name) = "web-1",
            "Agent name mismatch");
      end;
   end Test_Register_Request_Round_Trip;

   --  Test: Register_Response round-trip encode/decode
   procedure Test_Register_Response_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Register_Responses;
      Original : constant Register_Response :=
        (Node_Id => To_Unbounded_String ("node-42"));
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 2, "Expected 2 frames, got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert
           (Decoded in Register_Response,
            "Expected Register_Response");
         Assert
           (To_String (Register_Response (Decoded).Node_Id) = "node-42",
            "Node ID mismatch");
      end;
   end Test_Register_Response_Round_Trip;

   --  Test: Heartbeat_Message round-trip encode/decode
   procedure Test_Heartbeat_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Heartbeats;
      Now      : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Original : constant Heartbeat_Message :=
        (Agent_Id  => To_Unbounded_String ("node-42"),
         Timestamp => Now);
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 3, "Expected 3 frames, got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         use type Ada.Calendar.Time;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert
           (Decoded in Heartbeat_Message,
            "Expected Heartbeat_Message");
         Assert
           (To_String (Heartbeat_Message (Decoded).Agent_Id) = "node-42",
            "Agent ID mismatch");
         --  Timestamp survives round-trip through string formatting
         --  (sub-second precision may be lost)
         Assert
           (abs (Heartbeat_Message (Decoded).Timestamp - Now) < 1.0,
            "Timestamp drift exceeds 1 second");
      end;
   end Test_Heartbeat_Round_Trip;

   --  Stub decoder for Register test (library-level so 'Access is valid).
   function Stub_Decoder
     (Msg : in out CZMQ.Messages.Message)
      return Podmander.Messages.Protocol_Message'Class;

   function Stub_Decoder
     (Msg : in out CZMQ.Messages.Message)
      return Podmander.Messages.Protocol_Message'Class
   is
      pragma Unreferenced (Msg);
   begin
      return Podmander.Messages.Register_Requests.Register_Request'
        (Agent_Name => To_Unbounded_String (""));
   end Stub_Decoder;

   --  Test: Registering an already-registered kind raises Already_Registered
   procedure Test_Register_Duplicate_Kind
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Messages.Register
        (Podmander.Messages.Register_Kind, Stub_Decoder'Access);
      Assert (False, "Expected Already_Registered for duplicate kind");
   exception
      when Podmander.Messages.Already_Registered =>
         null;  --  Expected
   end Test_Register_Duplicate_Kind;

   --  Test: Decode of unknown message type raises Decode_Error
   procedure Test_Decode_Unknown_Kind
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Msg.Add_String ("bogus");
      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
         pragma Unreferenced (Decoded);
      begin
         Assert (False, "Expected Decode_Error for unknown kind");
      end;
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Decode_Unknown_Kind;

   overriding procedure Register_Tests (T : in out Message_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Register_Request_Round_Trip'Access,
         "Register_Request round-trip encode/decode");
      Register_Routine
        (T, Test_Register_Response_Round_Trip'Access,
         "Register_Response round-trip encode/decode");
      Register_Routine
        (T, Test_Heartbeat_Round_Trip'Access,
         "Heartbeat_Message round-trip encode/decode");
      Register_Routine
        (T, Test_Decode_Unknown_Kind'Access,
         "Decode of unknown message kind raises Decode_Error");
      Register_Routine
        (T, Test_Register_Duplicate_Kind'Access,
         "Registering an existing kind raises Already_Registered");
   end Register_Tests;

   --  Suite setup
   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Message_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Messages_Tests;
