--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ.Messages;
with Podmander.Agent.Podman;
with Podmander.Logging;
with Podmander.Messages.Deploy_Commands;

package body Podmander.Agent.Message_Handlers is

   overriding
   procedure Handle_Registration_Request
     (H : in out Agent_Handler; M : Podmander.Messages.Registration_Request_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning ("agent", "Registration_Request is agent-to-controller only");
   end Handle_Registration_Request;

   overriding
   procedure Handle_Heartbeat (H : in out Agent_Handler; M : Podmander.Messages.Heartbeat_Message_Type'Class) is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning ("agent", "Heartbeat is agent-to-controller only");
   end Handle_Heartbeat;

   overriding
   procedure Handle_Deploy_Command (H : in out Agent_Handler; M : Podmander.Messages.Deploy_Command_Type'Class) is
      use Podmander.Messages.Deploy_Commands;
      Cmd    : constant Deploy_Command := Deploy_Command (M);
      Name   : constant String := To_String (Cmd.Service_Name);
      Result : Podmander.Messages.Deploy_Results.Deploy_Result :=
        Podmander.Agent.Podman.Install_Quadlet (Service_Name => Name, Quadlet => To_String (Cmd.Quadlet));
   begin
      -- Echo catalog_id back as opaque correlation token
      Result.Catalog_Id := Cmd.Catalog_Id;
      Send_Deploy_Result (H, Result);
   end Handle_Deploy_Command;

   overriding
   procedure Handle_Deploy_Result (H : in out Agent_Handler; M : Podmander.Messages.Deploy_Result_Type'Class) is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning ("agent", "Deploy_Result is agent-to-controller only");
   end Handle_Deploy_Result;

   procedure Send_Deploy_Result (H : in out Agent_Handler; Result : Podmander.Messages.Deploy_Results.Deploy_Result) is
      use Podmander.Messages.Deploy_Results;
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Result.Encode (Msg);
      Msg.Send (H.Agt.Sock);
   end Send_Deploy_Result;

   overriding
   procedure Handle_Status_Query (H : in out Agent_Handler; M : Podmander.Messages.Status_Query_Type'Class) is
      pragma Unreferenced (M);
      Result : constant Podmander.Messages.Status_Responses.Status_Response := Podmander.Agent.Podman.List_Containers;
   begin
      Send_Status_Response (H, Result);
   end Handle_Status_Query;

   overriding
   procedure Handle_Status_Response (H : in out Agent_Handler; M : Podmander.Messages.Status_Response_Type'Class) is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning ("agent", "Status_Response is agent-to-controller only");
   end Handle_Status_Response;

   procedure Send_Status_Response
     (H : in out Agent_Handler; Result : Podmander.Messages.Status_Responses.Status_Response)
   is
      use Podmander.Messages.Status_Responses;
      Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
   begin
      Result.Encode (Msg);
      Msg.Send (H.Agt.Sock);
   end Send_Status_Response;

end Podmander.Agent.Message_Handlers;
