--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with CZMQ.Messages;
with Podmander.Agent.Deployer;
with Podmander.Agent.Status_Collector;
with Podmander.Logging;
with Podmander.Messages.Deploy_Commands;

package body Podmander.Agent.Message_Handlers is

   overriding procedure Handle_Register_Request
     (H : in out Agent_Handler;
      M : Podmander.Messages.Register_Request_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Register_Request is agent-to-controller only");
   end Handle_Register_Request;

   overriding procedure Handle_Heartbeat
     (H : in out Agent_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Heartbeat is agent-to-controller only");
   end Handle_Heartbeat;

   overriding procedure Handle_Deploy_Command
     (H : in out Agent_Handler;
      M : Podmander.Messages.Deploy_Command_Type'Class)
   is
      use Podmander.Messages.Deploy_Commands;
      Cmd    : constant Deploy_Command := Deploy_Command (M);
      Name   : constant String := To_String (Cmd.Service_Name);
      Result : constant Podmander.Messages.Deploy_Results.Deploy_Result :=
        Podmander.Agent.Deployer.Execute_Deploy
          (Service_Name => Name,
           Quadlet      => To_String (Cmd.Quadlet));
   begin
      Send_Deploy_Result (H, Result);
   end Handle_Deploy_Command;

   overriding procedure Handle_Deploy_Result
     (H : in out Agent_Handler;
      M : Podmander.Messages.Deploy_Result_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Deploy_Result is agent-to-controller only");
   end Handle_Deploy_Result;

   procedure Send_Deploy_Result
     (H      : in out Agent_Handler;
      Result : Podmander.Messages.Deploy_Results.Deploy_Result) is
   begin
      if H.Agt.Socket /= null then
         declare
            use Podmander.Messages.Deploy_Results;
            Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
         begin
            Result.Encode (Msg);
            Msg.Send (H.Agt.Socket.all);
         end;
      end if;
   end Send_Deploy_Result;

   overriding procedure Handle_Status_Query
     (H : in out Agent_Handler;
      M : Podmander.Messages.Status_Query_Type'Class)
   is
      pragma Unreferenced (M);
      Result : constant Podmander.Messages.Status_Responses.Status_Response :=
        Podmander.Agent.Status_Collector.Collect_Status;
   begin
      Send_Status_Response (H, Result);
   end Handle_Status_Query;

   overriding procedure Handle_Status_Response
     (H : in out Agent_Handler;
      M : Podmander.Messages.Status_Response_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("agent", "Status_Response is agent-to-controller only");
   end Handle_Status_Response;

   procedure Send_Status_Response
     (H      : in out Agent_Handler;
      Result : Podmander.Messages.Status_Responses.Status_Response) is
   begin
      if H.Agt.Socket /= null then
         declare
            use Podmander.Messages.Status_Responses;
            Msg : CZMQ.Messages.Message := CZMQ.Messages.New_Message;
         begin
            Result.Encode (Msg);
            Msg.Send (H.Agt.Socket.all);
         end;
      end if;
   end Send_Status_Response;

end Podmander.Agent.Message_Handlers;
