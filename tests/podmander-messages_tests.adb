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
with Podmander.Messages.Deploy_Commands;
with Podmander.Messages.Deploy_Results;
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Registration_Requests;
with Podmander.Messages.Registration_Responses;
with Podmander.Messages.Result_Codes;
with Podmander.Messages.Status_Queries;
with Podmander.Messages.Status_Responses;

package body Podmander.Messages_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Messages.Result_Codes;

   type Message_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Message_Test) return AUnit.Message_String
   is (AUnit.Format ("Message Protocol"));

   overriding
   procedure Register_Tests (T : in out Message_Test);

   --  Test: Registration_Request round-trip encode/decode
   procedure Test_Registration_Request_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Requests;
      Original : constant Registration_Request :=
        (Agent_Name => To_Unbounded_String ("web-1"), Enrollment_Secret => To_Unbounded_String ("secret123"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 3, "Expected 3 frames, got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Registration_Request, "Expected Registration_Request");
         Assert (To_String (Registration_Request (Decoded).Agent_Name) = "web-1", "Agent name mismatch");
         Assert
           (To_String (Registration_Request (Decoded).Enrollment_Secret) = "secret123", "Enrollment secret mismatch");
      end;
   end Test_Registration_Request_Round_Trip;

   --  Test: Registration_Response round-trip encode/decode
   procedure Test_Registration_Response_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Responses;
      Original : constant Registration_Response := (Node_Id => To_Unbounded_String ("node-42"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 2, "Expected 2 frames, got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Registration_Response, "Expected Registration_Response");
         Assert (To_String (Registration_Response (Decoded).Node_Id) = "node-42", "Node ID mismatch");
      end;
   end Test_Registration_Response_Round_Trip;

   --  Test: Heartbeat_Message round-trip encode/decode
   procedure Test_Heartbeat_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Heartbeats;
      Now      : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Original : constant Heartbeat_Message := (Node_Id => To_Unbounded_String ("node-42"), Timestamp => Now);
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 3, "Expected 3 frames, got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         use type Ada.Calendar.Time;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Heartbeat_Message, "Expected Heartbeat_Message");
         Assert (To_String (Heartbeat_Message (Decoded).Node_Id) = "node-42", "Node ID mismatch");
         --  Timestamp survives round-trip through string formatting
         --  (sub-second precision may be lost)
         Assert (abs (Heartbeat_Message (Decoded).Timestamp - Now) < 1.0, "Timestamp drift exceeds 1 second");
      end;
   end Test_Heartbeat_Round_Trip;

   --  Test: Deploy_Command round-trip encode/decode
   procedure Test_Deploy_Command_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Deploy_Commands;
      Original : constant Deploy_Command :=
        (Catalog_Id   => 42,
         Service_Name => To_Unbounded_String ("api"),
         Quadlet      => To_Unbounded_String ("[Unit]" & Character'Val (10) & "Name=api" & Character'Val (10)));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 4, "Expected 4 frames, got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Deploy_Command, "Expected Deploy_Command");
         Assert (Deploy_Command (Decoded).Catalog_Id = 42, "Catalog_Id mismatch");
         Assert (To_String (Deploy_Command (Decoded).Service_Name) = "api", "Service name mismatch");
         Assert
           (To_String (Deploy_Command (Decoded).Quadlet) = To_String (Original.Quadlet), "Quadlet content mismatch");
      end;
   end Test_Deploy_Command_Round_Trip;

   --  Test: Deploy_Result round-trip encode/decode (Ok)
   procedure Test_Deploy_Result_Ok_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Deploy_Results;
      Original : constant Deploy_Result :=
        (Catalog_Id    => 42,
         Code          => Podmander.Messages.Result_Codes.Ok,
         Service_Name  => To_Unbounded_String ("api"),
         Error_Message => To_Unbounded_String (""));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Deploy_Result, "Expected Deploy_Result");
         Assert (Deploy_Result (Decoded).Catalog_Id = 42, "Catalog_Id mismatch");
         Assert (Deploy_Result (Decoded).Code = Podmander.Messages.Result_Codes.Ok, "Expected Code = Ok");
         Assert (To_String (Deploy_Result (Decoded).Service_Name) = "api", "Service name mismatch");
         Assert (To_String (Deploy_Result (Decoded).Error_Message) = "", "Expected empty error message");
      end;
   end Test_Deploy_Result_Ok_Round_Trip;

   --  Test: Deploy_Result round-trip encode/decode (Failed)
   procedure Test_Deploy_Result_Failed_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Deploy_Results;
      Original : constant Deploy_Result :=
        (Catalog_Id    => 7,
         Code          => Podmander.Messages.Result_Codes.Failed,
         Service_Name  => To_Unbounded_String ("db"),
         Error_Message => To_Unbounded_String ("image pull failed"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Deploy_Result (Decoded).Code = Podmander.Messages.Result_Codes.Failed, "Expected Code = Failed");
         Assert (To_String (Deploy_Result (Decoded).Error_Message) = "image pull failed", "Error message mismatch");
      end;
   end Test_Deploy_Result_Failed_Round_Trip;

   --  Test: Deploy_Result round-trip encode/decode (Unavailable)
   procedure Test_Deploy_Result_Unavailable_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Deploy_Results;
      Original : constant Deploy_Result :=
        (Catalog_Id    => 99,
         Code          => Podmander.Messages.Result_Codes.Unavailable,
         Service_Name  => To_Unbounded_String ("svc"),
         Error_Message => To_Unbounded_String ("systemctl not found"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert
           (Deploy_Result (Decoded).Code = Podmander.Messages.Result_Codes.Unavailable, "Expected Code = Unavailable");
      end;
   end Test_Deploy_Result_Unavailable_Round_Trip;

   --  Test: Status_Query round-trip encode/decode
   procedure Test_Status_Query_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Status_Queries;
      Original : constant Status_Query := (null record);
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame, got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Status_Query, "Expected Status_Query");
      end;
   end Test_Status_Query_Round_Trip;

   --  Test: Status_Response round-trip encode/decode (Ok)
   procedure Test_Status_Response_Ok_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Status_Responses;
      Original : constant Status_Response :=
        (Code          => Podmander.Messages.Result_Codes.Ok,
         Containers    =>
           To_Unbounded_String
             ("web-1"
              & Character'Val (9)
              & "Up 2 hours"
              & Character'Val (10)
              & "db-1"
              & Character'Val (9)
              & "Up 3 hours"),
         Error_Message => To_Unbounded_String (""));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Status_Response, "Expected Status_Response");
         Assert (Status_Response (Decoded).Code = Podmander.Messages.Result_Codes.Ok, "Expected Code = Ok");
         Assert
           (To_String (Status_Response (Decoded).Containers) = To_String (Original.Containers),
            "Containers content mismatch");
         Assert (To_String (Status_Response (Decoded).Error_Message) = "", "Expected empty Error_Message");
      end;
   end Test_Status_Response_Ok_Round_Trip;

   --  Test: Status_Response round-trip encode/decode (Failed)
   procedure Test_Status_Response_Failed_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Podmander.Messages.Status_Responses;
      Original : constant Status_Response :=
        (Code          => Podmander.Messages.Result_Codes.Failed,
         Containers    => To_Unbounded_String (""),
         Error_Message => To_Unbounded_String ("podman ps failed"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Status_Response (Decoded).Code = Podmander.Messages.Result_Codes.Failed, "Expected Code = Failed");
         Assert (To_String (Status_Response (Decoded).Error_Message) = "podman ps failed", "Error_Message mismatch");
         Assert (To_String (Status_Response (Decoded).Containers) = "", "Expected empty Containers");
      end;
   end Test_Status_Response_Failed_Round_Trip;

   --  Test: Result_Code encode/decode round-trip
   procedure Test_Result_Code_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for Code in Result_Code loop
         Assert (Decode_Code (Encode_Code (Code)) = Code, "Round-trip failed for " & Result_Code'Image (Code));
      end loop;
   end Test_Result_Code_Round_Trip;

   --  Test: Decode_Code raises Decode_Error for unknown string
   procedure Test_Decode_Code_Unknown (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         Ignored : Result_Code;
         pragma Unreferenced (Ignored);
      begin
         Ignored := Decode_Code ("BOGUS");
         Assert (False, "Expected Decode_Error for unknown code");
      end;
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Decode_Code_Unknown;

   --  Stub decoder for Registration test (library-level so 'Access is valid).
   function Stub_Decoder (Msg : in out CZMQ.Messages.Message) return Podmander.Messages.Protocol_Message'Class;

   function Stub_Decoder (Msg : in out CZMQ.Messages.Message) return Podmander.Messages.Protocol_Message'Class is
      pragma Unreferenced (Msg);
   begin
      return
        Podmander.Messages.Registration_Requests.Registration_Request'
          (Agent_Name => To_Unbounded_String (""), Enrollment_Secret => To_Unbounded_String (""));
   end Stub_Decoder;

   --  Test: Registering an already-registered kind raises Already_Registered
   procedure Test_Register_Duplicate_Kind (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Podmander.Messages.Register (Podmander.Messages.Registration_Request_Kind, Stub_Decoder'Access);
      Assert (False, "Expected Already_Registered for duplicate kind");
   exception
      when Podmander.Messages.Already_Registered =>
         null;  --  Expected
   end Test_Register_Duplicate_Kind;

   --  Test: Decode of unknown message type raises Decode_Error
   procedure Test_Decode_Unknown_Kind (T : in out AUnit.Test_Cases.Test_Case'Class) is
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

   overriding
   procedure Register_Tests (T : in out Message_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Registration_Request_Round_Trip'Access, "Registration_Request round-trip encode/decode");
      Register_Routine
        (T, Test_Registration_Response_Round_Trip'Access, "Registration_Response round-trip encode/decode");
      Register_Routine (T, Test_Heartbeat_Round_Trip'Access, "Heartbeat_Message round-trip encode/decode");
      Register_Routine (T, Test_Deploy_Command_Round_Trip'Access, "Deploy_Command round-trip encode/decode");
      Register_Routine (T, Test_Deploy_Result_Ok_Round_Trip'Access, "Deploy_Result (success) round-trip encode/decode");
      Register_Routine
        (T, Test_Deploy_Result_Failed_Round_Trip'Access, "Deploy_Result (failure) round-trip encode/decode");
      Register_Routine
        (T, Test_Deploy_Result_Unavailable_Round_Trip'Access, "Deploy_Result (unavailable) round-trip encode/decode");
      Register_Routine (T, Test_Status_Query_Round_Trip'Access, "Status_Query round-trip encode/decode");
      Register_Routine (T, Test_Status_Response_Ok_Round_Trip'Access, "Status_Response round-trip encode/decode");
      Register_Routine
        (T, Test_Status_Response_Failed_Round_Trip'Access, "Status_Response (failure) round-trip encode/decode");
      Register_Routine (T, Test_Result_Code_Round_Trip'Access, "Result_Code round-trip encode/decode");
      Register_Routine (T, Test_Decode_Code_Unknown'Access, "Decode_Code raises Decode_Error for unknown string");
      Register_Routine (T, Test_Decode_Unknown_Kind'Access, "Decode of unknown message kind raises Decode_Error");
      Register_Routine
        (T, Test_Register_Duplicate_Kind'Access, "Registering an existing kind raises Already_Registered");
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
