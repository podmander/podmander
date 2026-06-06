--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ.Messages;
with Podmander.Agent.Podman;
with Podmander.Logging;
with Podmander.Messages.Deployment_Commands;

package body Podmander.Agent.Message_Handlers is

   overriding
   procedure Handle_Registration_Request
     (H : in out Agent_Handler;
      M : Podmander.Messages.Registration_Request_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Registration_Request is agent-to-controller only");
   end Handle_Registration_Request;

   overriding
   procedure Handle_Heartbeat
     (H : in out Agent_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Heartbeat is agent-to-controller only");
   end Handle_Heartbeat;

   overriding
   procedure Handle_Deployment_Command
     (H : in out Agent_Handler;
      M : Podmander.Messages.Deployment_Command_Type'Class)
   is
      use Podmander.Messages.Deployment_Commands;
      Cmd    : constant Deployment_Command := Deployment_Command (M);
      Name   : constant String := To_String (Cmd.Service_Name);
      Result : Podmander.Messages.Deployment_Results.Deployment_Result :=
        Podmander.Agent.Podman.Install_Quadlet
          (Service_Name => Name, Quadlet => To_String (Cmd.Quadlet));
   begin
      -- Echo catalog_id back as opaque correlation token
      Result.Catalog_Id := Cmd.Catalog_Id;
      Send_Deployment_Result (H, Result);
   end Handle_Deployment_Command;

   overriding
   procedure Handle_Deployment_Result
     (H : in out Agent_Handler;
      M : Podmander.Messages.Deployment_Result_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Deployment_Result is agent-to-controller only");
   end Handle_Deployment_Result;

   procedure Send_Deployment_Result
     (H      : in out Agent_Handler;
      Result : Podmander.Messages.Deployment_Results.Deployment_Result)
   is
      use Podmander.Messages.Deployment_Results;
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Result.Encode (Msg);
      Msg.Send (H.Agt.Sock);
   end Send_Deployment_Result;

   overriding
   procedure Handle_Status_Query
     (H : in out Agent_Handler; M : Podmander.Messages.Status_Query_Type'Class)
   is
      pragma Unreferenced (M);
      Result : constant Podmander.Messages.Status_Responses.Status_Response :=
        Podmander.Agent.Podman.List_Containers;
   begin
      Send_Status_Response (H, Result);
   end Handle_Status_Query;

   overriding
   procedure Handle_Status_Response
     (H : in out Agent_Handler;
      M : Podmander.Messages.Status_Response_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Status_Response is agent-to-controller only");
   end Handle_Status_Response;

   overriding
   procedure Handle_Stack_Submission
      (H : in out Agent_Handler;
       M : Podmander.Messages.Stack_Submission_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Stack_Submission is agent-to-controller only");
   end Handle_Stack_Submission;

   overriding
   procedure Handle_Stack_Submission_Result
      (H : in out Agent_Handler;
       M : Podmander.Messages.Stack_Submission_Result_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Stack_Submission_Result is controller-to-agent only");
   end Handle_Stack_Submission_Result;

   procedure Send_Status_Response
     (H      : in out Agent_Handler;
      Result : Podmander.Messages.Status_Responses.Status_Response)
   is
      use Podmander.Messages.Status_Responses;
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Result.Encode (Msg);
      Msg.Send (H.Agt.Sock);
   end Send_Status_Response;

end Podmander.Agent.Message_Handlers;
