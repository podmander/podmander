--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with CZMQ.Messages;
with GNATCOLL.JSON;
with Podmander.Messages;
with Podmander.Messages.All_Kinds;
pragma Unreferenced (Podmander.Messages.All_Kinds);
with Podmander.Messages.Deployment_Commands;
with Podmander.Messages.Deployment_Results;
with Podmander.Messages.Heartbeats;
with Podmander.Messages.JSON_Utils;
with Podmander.Messages.Registration_Requests;
with Podmander.Messages.Registration_Responses;
with Podmander.Messages.Result_Codes;
with Podmander.Messages.Status_Queries;
with Podmander.Messages.Status_Responses;
with Podmander.Messages.Stack_Submissions;
with Podmander.Messages.Stack_Submission_Results;

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

   -- Test: Registration_Request round-trip encode/decode
   procedure Test_Registration_Request_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Requests;
      Original : constant Registration_Request :=
        (Agent_Name        => To_Unbounded_String ("web-1"),
         Enrollment_Secret => To_Unbounded_String ("secret123"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame (JSON), got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert
           (Decoded in Registration_Request, "Expected Registration_Request");
         Assert
           (To_String (Registration_Request (Decoded).Agent_Name) = "web-1",
            "Agent name mismatch");
         Assert
           (To_String (Registration_Request (Decoded).Enrollment_Secret)
            = "secret123",
            "Enrollment secret mismatch");
      end;
   end Test_Registration_Request_Round_Trip;

   -- Test: Registration_Response round-trip encode/decode
   procedure Test_Registration_Response_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Registration_Responses;
      Original : constant Registration_Response :=
        (Connection_Id => To_Unbounded_String ("node-42"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame (JSON), got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert
           (Decoded in Registration_Response,
            "Expected Registration_Response");
         Assert
           (To_String (Registration_Response (Decoded).Connection_Id)
            = "node-42",
            "Connection ID mismatch");
      end;
   end Test_Registration_Response_Round_Trip;

   -- Test: Heartbeat_Message round-trip encode/decode
   procedure Test_Heartbeat_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Heartbeats;
      Now      : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Original : constant Heartbeat_Message :=
        (Connection_Id => To_Unbounded_String ("node-42"), Timestamp => Now);
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame (JSON), got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         use type Ada.Calendar.Time;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Heartbeat_Message, "Expected Heartbeat_Message");
         Assert
           (To_String (Heartbeat_Message (Decoded).Connection_Id) = "node-42",
            "Connection ID mismatch");
         -- Timestamp survives round-trip through string formatting
         -- (sub-second precision may be lost)
         Assert
           (abs (Heartbeat_Message (Decoded).Timestamp - Now) < 1.0,
            "Timestamp drift exceeds 1 second");
      end;
   end Test_Heartbeat_Round_Trip;

   -- Test: Deployment_Command round-trip encode/decode
   procedure Test_Deploy_Command_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Deployment_Commands;
      Original : constant Deployment_Command :=
        (Catalog_Id   => 42,
         Service_Name => To_Unbounded_String ("api"),
         Quadlet      =>
           To_Unbounded_String
             ("[Unit]"
              & Character'Val (10)
              & "Name=api"
              & Character'Val (10)));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame (JSON), got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Deployment_Command, "Expected Deployment_Command");
         Assert
           (Deployment_Command (Decoded).Catalog_Id = 42,
            "Catalog_Id mismatch");
         Assert
           (To_String (Deployment_Command (Decoded).Service_Name) = "api",
            "Service name mismatch");
         Assert
           (To_String (Deployment_Command (Decoded).Quadlet)
            = To_String (Original.Quadlet),
            "Quadlet content mismatch");
      end;
   end Test_Deploy_Command_Round_Trip;

   -- Test: Deployment_Result round-trip encode/decode (Ok)
   procedure Test_Deploy_Result_Ok_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Deployment_Results;
      Original : constant Deployment_Result :=
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
         Assert (Decoded in Deployment_Result, "Expected Deployment_Result");
         Assert
           (Deployment_Result (Decoded).Catalog_Id = 42,
            "Catalog_Id mismatch");
         Assert
           (Deployment_Result (Decoded).Code
            = Podmander.Messages.Result_Codes.Ok,
            "Expected Code = Ok");
         Assert
           (To_String (Deployment_Result (Decoded).Service_Name) = "api",
            "Service name mismatch");
         Assert
           (To_String (Deployment_Result (Decoded).Error_Message) = "",
            "Expected empty error message");
      end;
   end Test_Deploy_Result_Ok_Round_Trip;

   -- Test: Deployment_Result round-trip encode/decode (Failed)
   procedure Test_Deploy_Result_Failed_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Deployment_Results;
      Original : constant Deployment_Result :=
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
         Assert
           (Deployment_Result (Decoded).Code
            = Podmander.Messages.Result_Codes.Failed,
            "Expected Code = Failed");
         Assert
           (To_String (Deployment_Result (Decoded).Error_Message)
            = "image pull failed",
            "Error message mismatch");
      end;
   end Test_Deploy_Result_Failed_Round_Trip;

   -- Test: Deployment_Result round-trip encode/decode (Unavailable)
   procedure Test_Deploy_Result_Unavailable_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Deployment_Results;
      Original : constant Deployment_Result :=
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
           (Deployment_Result (Decoded).Code
            = Podmander.Messages.Result_Codes.Unavailable,
            "Expected Code = Unavailable");
      end;
   end Test_Deploy_Result_Unavailable_Round_Trip;

   -- Test: Status_Query round-trip encode/decode
   procedure Test_Status_Query_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Status_Queries;
      Original : constant Status_Query := (null record);
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame (JSON), got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Status_Query, "Expected Status_Query");
      end;
   end Test_Status_Query_Round_Trip;

   -- Test: Status_Response round-trip encode/decode (Ok)
   procedure Test_Status_Response_Ok_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
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
         Assert
           (Status_Response (Decoded).Code
            = Podmander.Messages.Result_Codes.Ok,
            "Expected Code = Ok");
         Assert
           (To_String (Status_Response (Decoded).Containers)
            = To_String (Original.Containers),
            "Containers content mismatch");
         Assert
           (To_String (Status_Response (Decoded).Error_Message) = "",
            "Expected empty Error_Message");
      end;
   end Test_Status_Response_Ok_Round_Trip;

   -- Test: Status_Response round-trip encode/decode (Failed)
   procedure Test_Status_Response_Failed_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
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
         Assert
           (Status_Response (Decoded).Code
            = Podmander.Messages.Result_Codes.Failed,
            "Expected Code = Failed");
         Assert
           (To_String (Status_Response (Decoded).Error_Message)
            = "podman ps failed",
            "Error_Message mismatch");
         Assert
           (To_String (Status_Response (Decoded).Containers) = "",
            "Expected empty Containers");
      end;
   end Test_Status_Response_Failed_Round_Trip;

   -- Test: Result_Code encode/decode round-trip
   procedure Test_Result_Code_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      for Code in Result_Code loop
         Assert
           (Decode_Code (Encode_Code (Code)) = Code,
            "Round-trip failed for " & Result_Code'Image (Code));
      end loop;
   end Test_Result_Code_Round_Trip;

   -- Test: Decode_Code raises Decode_Error for unknown string
   procedure Test_Decode_Code_Unknown
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
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

   -- Test: Stack_Submission round-trip encode/decode
   procedure Test_Stack_Submission_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Stack_Submissions;
      Original : constant Stack_Submission :=
        (TOML              =>
           To_Unbounded_String
             ("[container]" & Character'Val (10) & "name = ""web"""),
         Enrollment_Secret => To_Unbounded_String ("secret456"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame (JSON), got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert (Decoded in Stack_Submission, "Expected Stack_Submission");
         Assert
           (To_String (Stack_Submission (Decoded).TOML)
            = To_String (Original.TOML),
            "TOML content mismatch");
         Assert
           (To_String (Stack_Submission (Decoded).Enrollment_Secret)
            = "secret456",
            "Enrollment_Secret mismatch");
      end;
   end Test_Stack_Submission_Round_Trip;

   -- Test: Stack_Submission_Result round-trip encode/decode (success)
   procedure Test_Stack_Submission_Result_Success_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Stack_Submission_Results;
      Original : constant Stack_Submission_Result :=
        (Success => True, Message => To_Unbounded_String ("stack deployed"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame (JSON), got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert
           (Decoded in Stack_Submission_Result,
            "Expected Stack_Submission_Result");
         Assert
           (Stack_Submission_Result (Decoded).Success = True,
            "Expected Success = True");
         Assert
           (To_String (Stack_Submission_Result (Decoded).Message)
            = "stack deployed",
            "Message mismatch");
      end;
   end Test_Stack_Submission_Result_Success_Round_Trip;

   -- Test: Stack_Submission_Result round-trip encode/decode (failure)
   procedure Test_Stack_Submission_Result_Failure_Round_Trip
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Stack_Submission_Results;
      Original : constant Stack_Submission_Result :=
        (Success => False, Message => To_Unbounded_String ("invalid TOML"));
      Msg      : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Original.Encode (Msg);
      Assert (Msg.Size = 1, "Expected 1 frame (JSON), got" & Msg.Size'Image);

      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
      begin
         Assert
           (Decoded in Stack_Submission_Result,
            "Expected Stack_Submission_Result");
         Assert
           (Stack_Submission_Result (Decoded).Success = False,
            "Expected Success = False");
         Assert
           (To_String (Stack_Submission_Result (Decoded).Message)
            = "invalid TOML",
            "Message mismatch");
      end;
   end Test_Stack_Submission_Result_Failure_Round_Trip;

   -- Test: Decode of Stack_Submission_Result with invalid success field raises Decode_Error
   procedure Test_Stack_Submission_Result_Invalid_Success
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      -- Manually craft a message with an invalid "success" value
      Msg.Add_String
        ("""{""""kind"""": """"stack_submission_ack"""", """"success"""": """"maybe"""", """"message"""": """"test""""}""");
      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
         pragma Unreferenced (Decoded);
      begin
         Assert (False, "Expected Decode_Error for invalid success field");
      end;
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Stack_Submission_Result_Invalid_Success;

   -- Stub decoder for Registration test (library-level so 'Access is valid).
   function Stub_Decoder
     (Obj : GNATCOLL.JSON.JSON_Value)
      return Podmander.Messages.Protocol_Message'Class;

   function Stub_Decoder
     (Obj : GNATCOLL.JSON.JSON_Value)
      return Podmander.Messages.Protocol_Message'Class
   is
      pragma Unreferenced (Obj);
   begin
      return
        Podmander.Messages.Registration_Requests.Registration_Request'
          (Agent_Name        => To_Unbounded_String (""),
           Enrollment_Secret => To_Unbounded_String (""));
   end Stub_Decoder;

   -- Test: Registering an already-registered kind raises Already_Registered
   procedure Test_Register_Duplicate_Kind
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Podmander.Messages.Register
        (Podmander.Messages.Registration_Request_Kind, Stub_Decoder'Access);
      Assert (False, "Expected Already_Registered for duplicate kind");
   exception
      when Podmander.Messages.Already_Registered =>
         null;  --  Expected
   end Test_Register_Duplicate_Kind;

   -- Test: Decode of unknown message type raises Decode_Error
   procedure Test_Decode_Unknown_Kind
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Msg.Add_String ("""{""""kind"""": """"bogus""""}""");
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

   -- Test: Decode of malformed JSON raises Decode_Error
   procedure Test_Decode_Malformed_JSON
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Msg.Add_String ("not json at all");
      declare
         use Podmander.Messages;
         Decoded : constant Protocol_Message'Class := Decode (Msg);
         pragma Unreferenced (Decoded);
      begin
         Assert (False, "Expected Decode_Error for malformed JSON");
      end;
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Decode_Malformed_JSON;

   -- JSON_Utils tests

   -- Test: Get_Kind returns the same value that was set
   procedure Test_Get_Kind (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Podmander.Messages.JSON_Utils.Set_Kind (Obj, "deploy");
      Assert
        (Podmander.Messages.JSON_Utils.Get_Kind (Obj) = "deploy",
         "Get_Kind did not return the expected value");
   end Test_Get_Kind;

   -- Test: Get_Kind raises Decode_Error on missing field
   procedure Test_Get_Kind_Missing
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      declare
         Ignored : constant String :=
           Podmander.Messages.JSON_Utils.Get_Kind (Obj);
         pragma Unreferenced (Ignored);
      begin
         Assert (False, "Expected Decode_Error for missing kind field");
      end;
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Get_Kind_Missing;

   -- Test: Set_Kind then Get_Kind round-trip
   procedure Test_Set_Kind_And_Get_Kind
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Podmander.Messages.JSON_Utils.Set_Kind (Obj, "deploy");
      Assert
        (Podmander.Messages.JSON_Utils.Get_Kind (Obj) = "deploy",
         "Set_Kind then Get_Kind did not round-trip correctly");
   end Test_Set_Kind_And_Get_Kind;

   -- Test: Get_Field (String) returns the value that was set
   procedure Test_Get_Field_String
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Podmander.Messages.JSON_Utils.Set_Field (Obj, "name", "web-1");
      Assert
        (Podmander.Messages.JSON_Utils.Get_Field (Obj, "name") = "web-1",
         "Get_Field (String) did not return the expected value");
   end Test_Get_Field_String;

   -- Test: Get_Field (String) raises Decode_Error on missing field
   procedure Test_Get_Field_String_Missing
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      declare
         Ignored : constant String :=
           Podmander.Messages.JSON_Utils.Get_Field (Obj, "name");
         pragma Unreferenced (Ignored);
      begin
         Assert (False, "Expected Decode_Error for missing string field");
      end;
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Get_Field_String_Missing;

   -- Test: Get_Field (Integer) returns the value that was set
   procedure Test_Get_Field_Integer
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Podmander.Messages.JSON_Utils.Set_Field (Obj, "catalog_id", 42);
      Assert
        (Podmander.Messages.JSON_Utils.Get_Field (Obj, "catalog_id") = 42,
         "Get_Field (Integer) did not return the expected value");
   end Test_Get_Field_Integer;

   -- Test: Get_Field (Integer) raises Decode_Error on missing field
   procedure Test_Get_Field_Integer_Missing
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj     : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
      Ignored : Integer;
      pragma Unreferenced (Ignored);
   begin
      Ignored := Podmander.Messages.JSON_Utils.Get_Field (Obj, "catalog_id");
      Assert (False, "Expected Decode_Error for missing integer field");
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Get_Field_Integer_Missing;

   -- Test: Get_Field (Time) returns a value within 1 second of the original
   procedure Test_Get_Field_Time (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Podmander.Messages.JSON_Utils.Set_Field (Obj, "ts", Now);
      declare
         use type Ada.Calendar.Time;
         Result : constant Ada.Calendar.Time :=
           Podmander.Messages.JSON_Utils.Get_Field (Obj, "ts");
      begin
         Assert (abs (Result - Now) < 1.0, "Timestamp drift exceeds 1 second");
      end;
   end Test_Get_Field_Time;

   -- Test: Get_Field (Time) raises Decode_Error on missing field
   procedure Test_Get_Field_Time_Missing
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj     : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
      Ignored : Ada.Calendar.Time;
      pragma Unreferenced (Ignored);
   begin
      Ignored := Podmander.Messages.JSON_Utils.Get_Field (Obj, "ts");
      Assert (False, "Expected Decode_Error for missing timestamp field");
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Get_Field_Time_Missing;

   -- Test: Set_Field (String) stores value accessible via GNATCOLL directly
   procedure Test_Set_Field_String
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Podmander.Messages.JSON_Utils.Set_Field (Obj, "name", "test");
      declare
         Name : constant String := Obj.Get ("name");
      begin
         Assert
           (Name = "test",
            "Set_Field (String) did not store the correct value");
      end;
   end Test_Set_Field_String;

   -- Test: Set_Field (Integer) stores value accessible via GNATCOLL directly
   procedure Test_Set_Field_Integer
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Podmander.Messages.JSON_Utils.Set_Field (Obj, "count", 7);
      declare
         Count : constant Integer := Obj.Get ("count");
      begin
         Assert
           (Count = 7, "Set_Field (Integer) did not store the correct value");
      end;
   end Test_Set_Field_Integer;

   -- Test: Set_Field (Time) creates a string field accessible via GNATCOLL
   procedure Test_Set_Field_Time (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type GNATCOLL.JSON.JSON_Value_Type;
      Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Obj : GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Podmander.Messages.JSON_Utils.Set_Field (Obj, "ts", Now);
      Assert
        (Obj.Has_Field ("ts"), "Set_Field (Time) did not create the field");
      Assert
        (Obj.Get ("ts").Kind = GNATCOLL.JSON.JSON_String_Type,
         "Set_Field (Time) did not store a string value");
   end Test_Set_Field_Time;

   -- Test: Result_Code JSON encode/decode round-trip
   procedure Test_Result_Code_Round_Trip_JSON
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Result_Codes;
   begin
      for Code in Result_Code loop
         Assert
           (Podmander.Messages.JSON_Utils.Decode_Code
              (Podmander.Messages.JSON_Utils.Encode_Code (Code))
            = Code,
            "JSON round-trip failed for " & Result_Code'Image (Code));
      end loop;
   end Test_Result_Code_Round_Trip_JSON;

   -- Test: JSON_Utils.Decode_Code raises Decode_Error for unknown string
   procedure Test_Decode_Code_Unknown_JSON
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Podmander.Messages.Result_Codes;
   begin
      declare
         Ignored : Result_Code;
         pragma Unreferenced (Ignored);
      begin
         Ignored := Podmander.Messages.JSON_Utils.Decode_Code ("BOGUS");
         Assert (False, "Expected Decode_Error for unknown code");
      end;
   exception
      when Podmander.Messages.Decode_Error =>
         null;  --  Expected
   end Test_Decode_Code_Unknown_JSON;

   overriding
   procedure Register_Tests (T : in out Message_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Registration_Request_Round_Trip'Access,
         "Registration_Request round-trip encode/decode");
      Register_Routine
        (T,
         Test_Registration_Response_Round_Trip'Access,
         "Registration_Response round-trip encode/decode");
      Register_Routine
        (T,
         Test_Heartbeat_Round_Trip'Access,
         "Heartbeat_Message round-trip encode/decode");
      Register_Routine
        (T,
         Test_Deploy_Command_Round_Trip'Access,
         "Deployment_Command round-trip encode/decode");
      Register_Routine
        (T,
         Test_Deploy_Result_Ok_Round_Trip'Access,
         "Deployment_Result (success) round-trip encode/decode");
      Register_Routine
        (T,
         Test_Deploy_Result_Failed_Round_Trip'Access,
         "Deployment_Result (failure) round-trip encode/decode");
      Register_Routine
        (T,
         Test_Deploy_Result_Unavailable_Round_Trip'Access,
         "Deployment_Result (unavailable) round-trip encode/decode");
      Register_Routine
        (T,
         Test_Status_Query_Round_Trip'Access,
         "Status_Query round-trip encode/decode");
      Register_Routine
        (T,
         Test_Status_Response_Ok_Round_Trip'Access,
         "Status_Response round-trip encode/decode");
      Register_Routine
        (T,
         Test_Status_Response_Failed_Round_Trip'Access,
         "Status_Response (failure) round-trip encode/decode");
      Register_Routine
        (T,
         Test_Stack_Submission_Round_Trip'Access,
         "Stack_Submission round-trip encode/decode");
      Register_Routine
        (T,
         Test_Stack_Submission_Result_Success_Round_Trip'Access,
         "Stack_Submission_Result (success) round-trip encode/decode");
      Register_Routine
        (T,
         Test_Stack_Submission_Result_Failure_Round_Trip'Access,
         "Stack_Submission_Result (failure) round-trip encode/decode");
      Register_Routine
        (T,
         Test_Stack_Submission_Result_Invalid_Success'Access,
         "Stack_Submission_Result with invalid success field raises Decode_Error");
      Register_Routine
        (T,
         Test_Result_Code_Round_Trip'Access,
         "Result_Code round-trip encode/decode");
      Register_Routine
        (T,
         Test_Decode_Code_Unknown'Access,
         "Decode_Code raises Decode_Error for unknown string");
      Register_Routine
        (T,
         Test_Decode_Unknown_Kind'Access,
         "Decode of unknown message kind raises Decode_Error");
      Register_Routine
        (T,
         Test_Decode_Malformed_JSON'Access,
         "Decode of malformed JSON raises Decode_Error");
      Register_Routine
        (T,
         Test_Register_Duplicate_Kind'Access,
         "Registering an existing kind raises Already_Registered");
      -- JSON_Utils tests
      Register_Routine (T, Test_Get_Kind'Access, "Get_Kind returns set value");
      Register_Routine
        (T,
         Test_Get_Kind_Missing'Access,
         "Get_Kind raises Decode_Error for missing field");
      Register_Routine
        (T,
         Test_Set_Kind_And_Get_Kind'Access,
         "Set_Kind then Get_Kind round-trip");
      Register_Routine
        (T,
         Test_Get_Field_String'Access,
         "Get_Field (String) returns set value");
      Register_Routine
        (T,
         Test_Get_Field_String_Missing'Access,
         "Get_Field (String) raises Decode_Error for missing field");
      Register_Routine
        (T,
         Test_Get_Field_Integer'Access,
         "Get_Field (Integer) returns set value");
      Register_Routine
        (T,
         Test_Get_Field_Integer_Missing'Access,
         "Get_Field (Integer) raises Decode_Error for missing field");
      Register_Routine
        (T,
         Test_Get_Field_Time'Access,
         "Get_Field (Time) returns value within 1 second");
      Register_Routine
        (T,
         Test_Get_Field_Time_Missing'Access,
         "Get_Field (Time) raises Decode_Error for missing field");
      Register_Routine
        (T,
         Test_Set_Field_String'Access,
         "Set_Field (String) stores value via GNATCOLL");
      Register_Routine
        (T,
         Test_Set_Field_Integer'Access,
         "Set_Field (Integer) stores value via GNATCOLL");
      Register_Routine
        (T,
         Test_Set_Field_Time'Access,
         "Set_Field (Time) stores string field via GNATCOLL");
      Register_Routine
        (T,
         Test_Result_Code_Round_Trip_JSON'Access,
         "Result_Code JSON encode/decode round-trip");
      Register_Routine
        (T,
         Test_Decode_Code_Unknown_JSON'Access,
         "JSON_Utils.Decode_Code raises Decode_Error for unknown code");
   end Register_Tests;

   -- Suite setup
   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Message_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Messages_Tests;
