--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

--  Behavioral tests for Podmander.Control_Channel.
--  Real ROUTER/DEALER sockets over inproc exercise the send and receive paths
--  end to end; no mocks. A DEALER with a fixed identity lets the ROUTER learn
--  the route, so the addressed-send path can be driven deterministically.

with Ada.Calendar;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with AUnit.Test_Cases;
with CZMQ.Certificates;
with CZMQ.Messages;
with CZMQ.Sockets;
with Podmander.Control_Channel;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Registration_Responses;

package body Podmander.Control_Channel_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   package CC renames Podmander.Control_Channel;
   use type CC.Receive_Outcome;

   type CC_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : CC_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Control_Channel"));

   overriding
   procedure Register_Tests (T : in out CC_Test);

   --  Connect a DEALER with a fixed identity to a bound ROUTER endpoint.
   procedure Open_Dealer
     (Dealer            : in out CZMQ.Sockets.Socket;
      Endpoint          : String;
      Identity          : String;
      Server_Public_Key : String)
   is
      Client_Cert : CZMQ.Certificates.Certificate;
   begin
      Client_Cert.Generate;
      CZMQ.Sockets.Open_Dealer (Dealer);
      Client_Cert.Apply (Dealer);
      Dealer.Set_Curve_Serverkey (Server_Public_Key);
      Dealer.Set_Identity (Identity);
      Dealer.Set_Receive_Timeout (1000);
      Dealer.Connect (Endpoint);
   end Open_Dealer;

   --  Send one encoded protocol message from a DEALER (no identity frame; the
   --  ROUTER prepends the sender's identity on receipt).
   procedure Dealer_Send
     (Dealer  : in out CZMQ.Sockets.Socket;
      Message : Podmander.Messages.Protocol_Message'Class)
   is
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Message.Encode (Msg);
      Msg.Send (Dealer);
   end Dealer_Send;

   --  Test 1: Send on an unopened socket is a no-op, not an error. This is the
   --  seam that lets handler logic run without a live socket.
   procedure Test_Send_Unopened_Is_Noop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Chan : CC.Channel;
      Resp :
        constant Podmander
                   .Messages
                   .Registration_Responses
                   .Registration_Response :=
          (Connection_Id => To_Unbounded_String ("nobody"));
   begin
      Chan.Send ("nobody", Resp);
      Assert (True, "Send on an unopened socket must not raise");
   end Test_Send_Unopened_Is_Noop;

   procedure Test_Listen_Rejects_Invalid_Certificate
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cert : CZMQ.Certificates.Certificate;
      Chan : CC.Channel;
   begin
      Chan.Listen ("inproc://cc-test-invalid-cert", Cert);
      Assert (False, "Listen must reject an invalid controller certificate");
   exception
      when CC.Invalid_Certificate =>
         Assert (True, "Listen rejects an invalid controller certificate");
   end Test_Listen_Rejects_Invalid_Certificate;

   --  Test 2: Send on a bound ROUTER with no connected peer drops the message
   --  silently (mandatory routing is off) and must not raise.
   procedure Test_Send_No_Peer_Is_Noop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cert : CZMQ.Certificates.Certificate;
      Chan : CC.Channel;
      Resp :
        constant Podmander
                   .Messages
                   .Registration_Responses
                   .Registration_Response :=
          (Connection_Id => To_Unbounded_String ("ghost"));
   begin
      Cert.Generate;
      Chan.Listen ("inproc://cc-test-send-no-peer", Cert);
      Chan.Send ("ghost", Resp);
      Chan.Close;
      Assert (True, "Send to an unknown identity must not raise");
   end Test_Send_No_Peer_Is_Noop;

   --  Test 3: Send addressed to a known identity reaches that DEALER, which
   --  decodes the original message. The DEALER first primes the ROUTER's
   --  routing table by sending one message inbound.
   procedure Test_Send_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Endpoint : constant String := "inproc://cc-test-send-round-trip";
      Cert     : CZMQ.Certificates.Certificate;
      Dealer   : CZMQ.Sockets.Socket;
      Chan     : CC.Channel;
      Id       : Unbounded_String;
      Holder   : CC.Message_Holders.Holder;
      Outcome  : CC.Receive_Outcome;
      Resp     :
        constant Podmander
                   .Messages
                   .Registration_Responses
                   .Registration_Response :=
          (Connection_Id => To_Unbounded_String ("web-1"));
   begin
      Cert.Generate;
      Chan.Listen (Endpoint, Cert);
      Open_Dealer (Dealer, Endpoint, "web-1", Cert.Public_Key);

      --  Prime: DEALER -> ROUTER so the ROUTER learns the "web-1" route.
      Dealer_Send (Dealer, Resp);
      Chan.Receive (Id, Holder, Outcome);
      Assert (Outcome = CC.Message_Received, "Priming receive must succeed");

      --  Now ROUTER -> DEALER addressed by the learned identity.
      Chan.Send ("web-1", Resp);

      declare
         Reply  : CZMQ.Messages.Message;
         Status : CZMQ.Messages.Receive_Status;
         use type CZMQ.Messages.Receive_Status;
      begin
         CZMQ.Messages.Receive (Dealer, Reply, Status);
         Assert
           (Status = CZMQ.Messages.Success,
            "DEALER must receive the addressed message");
         declare
            Decoded : constant Podmander.Messages.Protocol_Message'Class :=
              Podmander.Messages.Decode (Reply);
         begin
            Assert
              (Decoded in Podmander.Messages.Registration_Response_Type'Class,
               "DEALER must decode a Registration_Response");
         end;
      end;
      Chan.Close;
   end Test_Send_Round_Trip;

   --  Test 4: Receive pops the routing identity and decodes the payload into
   --  the matching protocol message.
   procedure Test_Receive_Decodes_And_Identifies
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Endpoint : constant String := "inproc://cc-test-receive-decode";
      Cert     : CZMQ.Certificates.Certificate;
      Dealer   : CZMQ.Sockets.Socket;
      Chan     : CC.Channel;
      Id       : Unbounded_String;
      Holder   : CC.Message_Holders.Holder;
      Outcome  : CC.Receive_Outcome;
      HB       : constant Podmander.Messages.Heartbeats.Heartbeat_Message :=
        (Connection_Id => To_Unbounded_String ("agent-9"),
         Timestamp     => Ada.Calendar.Clock);
   begin
      Cert.Generate;
      Chan.Listen (Endpoint, Cert);
      Open_Dealer (Dealer, Endpoint, "agent-9", Cert.Public_Key);

      Dealer_Send (Dealer, HB);
      Chan.Receive (Id, Holder, Outcome);

      Assert (Outcome = CC.Message_Received, "Expected Message_Received");
      Assert (To_String (Id) = "agent-9", "Identity must be the DEALER's id");
      declare
         Decoded : constant Podmander.Messages.Protocol_Message'Class :=
           CC.Message_Holders.Element (Holder);
      begin
         Assert
           (Decoded in Podmander.Messages.Heartbeat_Message_Type'Class,
            "Decoded message must be a Heartbeat");
      end;
      Chan.Close;
   end Test_Receive_Decodes_And_Identifies;

   --  Test 5: Receive on an idle socket reports No_Message rather than blocking.
   procedure Test_Receive_Timeout_Is_No_Message
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Cert    : CZMQ.Certificates.Certificate;
      Chan    : CC.Channel;
      Id      : Unbounded_String;
      Holder  : CC.Message_Holders.Holder;
      Outcome : CC.Receive_Outcome;
   begin
      Cert.Generate;
      Chan.Listen ("inproc://cc-test-receive-timeout", Cert);

      Chan.Receive (Id, Holder, Outcome);
      Chan.Close;
      Assert (Outcome = CC.No_Message, "Idle receive must report No_Message");
   end Test_Receive_Timeout_Is_No_Message;

   --  Test 6: A frame that fails to decode reports Malformed, with the sender's
   --  identity preserved so the caller can report it.
   procedure Test_Receive_Malformed_Reports_Malformed
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Endpoint : constant String := "inproc://cc-test-receive-malformed";
      Cert     : CZMQ.Certificates.Certificate;
      Dealer   : CZMQ.Sockets.Socket;
      Chan     : CC.Channel;
      Id       : Unbounded_String;
      Holder   : CC.Message_Holders.Holder;
      Outcome  : CC.Receive_Outcome;
   begin
      Cert.Generate;
      Chan.Listen (Endpoint, Cert);
      Open_Dealer (Dealer, Endpoint, "garbler", Cert.Public_Key);

      declare
         Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
      begin
         Msg.Add_String ("this is not json");
         Msg.Send (Dealer);
      end;

      Chan.Receive (Id, Holder, Outcome);
      Assert
        (Outcome = CC.Malformed, "Undecodable frame must report Malformed");
      Assert
        (To_String (Id) = "garbler",
         "Malformed receive must still surface the sender identity");
      Chan.Close;
   end Test_Receive_Malformed_Reports_Malformed;

   overriding
   procedure Register_Tests (T : in out CC_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Send_Unopened_Is_Noop'Access,
         "Send on an unopened socket is a no-op");
      Register_Routine
        (T,
         Test_Listen_Rejects_Invalid_Certificate'Access,
         "Listen rejects an invalid controller certificate");
      Register_Routine
        (T,
         Test_Send_No_Peer_Is_Noop'Access,
         "Send to an unknown identity is a no-op");
      Register_Routine
        (T, Test_Send_Round_Trip'Access, "Send reaches an addressed DEALER");
      Register_Routine
        (T,
         Test_Receive_Decodes_And_Identifies'Access,
         "Receive decodes the payload and surfaces the sender identity");
      Register_Routine
        (T,
         Test_Receive_Timeout_Is_No_Message'Access,
         "Receive on an idle socket reports No_Message");
      Register_Routine
        (T,
         Test_Receive_Malformed_Reports_Malformed'Access,
         "Receive of an undecodable frame reports Malformed");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased CC_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Control_Channel_Tests;
