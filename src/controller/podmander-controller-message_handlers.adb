--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with CZMQ.Messages;
with Podmander.Enrollment;
with Podmander.Logging;
with Podmander.Messages.Deploy_Results;
with Podmander.Messages.Registration_Requests;
with Podmander.Messages.Registration_Responses;
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Result_Codes;
with Podmander.Messages.Status_Queries;
with Podmander.Messages.Status_Responses;

package body Podmander.Controller.Message_Handlers is

   procedure Send_Status_Query
     (H       : in out Controller_Handler;
      Node_Id : String) is
      use Podmander.Messages.Status_Queries;
      Query : constant Status_Query := (null record);
      Msg   : CZMQ.Messages.Message :=
        CZMQ.Messages.New_Message;
   begin
      Msg.Add_String (Node_Id);
      Query.Encode (Msg);
      Msg.Send (H.Ctrl.Socket);
      Podmander.Logging.Info
        ("controller",
         "Sent status query to " & Node_Id);
   end Send_Status_Query;

    overriding procedure Handle_Registration_Request
      (H : in out Controller_Handler;
       M : Podmander.Messages.Registration_Request_Type'Class)
    is
       use Podmander.Messages.Registration_Requests;
       use Podmander.Messages.Registration_Responses;
       Req     : constant Registration_Request := Registration_Request (M);
       Name    : constant String := To_String (Req.Agent_Name);
       Node_Id : constant String := To_String (H.Identity);
    begin
       if not Podmander.Enrollment.Secret_Matches
         (H.Ctrl.Config.Enrollment, To_String (Req.Enrollment_Secret))
       then
          Podmander.Logging.Warning
            ("controller",
             "Invalid enrollment secret from agent """
             & Name & """");
          return;
       end if;

       declare
          Info : constant Podmander.Types.Agent_Info :=
            (Name      => Req.Agent_Name,
             Node_Id   => To_Unbounded_String (Node_Id),
             State     => Podmander.Types.Registered,
             Last_Seen => Ada.Calendar.Clock);
       begin
          H.Ctrl.Agents.Include (Node_Id, Info);
          Podmander.Logging.Info
            ("controller",
             "Registered agent """ & Name & """ as " & Node_Id);
       end;

       if H.Ctrl.Socket.Is_Valid then
          declare
             Reply     : constant Registration_Response :=
               (Node_Id => To_Unbounded_String (Node_Id));
             Reply_Msg : CZMQ.Messages.Message :=
               CZMQ.Messages.New_Message;
          begin
             Reply_Msg.Add_String (Node_Id);
             Reply.Encode (Reply_Msg);
             Reply_Msg.Send (H.Ctrl.Socket);
          end;

          Send_Status_Query (H, Node_Id);
       end if;
    end Handle_Registration_Request;

   overriding procedure Handle_Heartbeat
     (H : in out Controller_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class)
   is
      use Podmander.Messages.Heartbeats;
      HB       : constant Heartbeat_Message := Heartbeat_Message (M);
      Agent_Id : constant String := To_String (HB.Agent_Id);
   begin
      if H.Ctrl.Agents.Contains (Agent_Id) then
         declare
            Info : Podmander.Types.Agent_Info := H.Ctrl.Agents (Agent_Id);
         begin
            Info.Last_Seen := Ada.Calendar.Clock;
            if Info.State /= Podmander.Types.Registered then
               Podmander.Logging.Info
                 ("controller",
                  "Agent " & Agent_Id & " reconnected");
               Info.State := Podmander.Types.Registered;
            end if;
            H.Ctrl.Agents.Replace (Agent_Id, Info);
            Podmander.Logging.Debug
              ("controller", "Heartbeat from " & Agent_Id);
         end;
      else
         Podmander.Logging.Warning
           ("controller",
            "Heartbeat from unregistered agent "
            & To_String (H.Identity) & ", ignoring");
      end if;
   end Handle_Heartbeat;

   overriding procedure Handle_Deploy_Command
     (H : in out Controller_Handler;
      M : Podmander.Messages.Deploy_Command_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("controller", "Deploy_Command is controller-to-agent only");
   end Handle_Deploy_Command;

   overriding procedure Handle_Deploy_Result
     (H : in out Controller_Handler;
      M : Podmander.Messages.Deploy_Result_Type'Class)
   is
      use Podmander.Messages.Deploy_Results;
      use type Podmander.Messages.Result_Codes.Result_Code;
      Result : constant Deploy_Result := Deploy_Result (M);
   begin
      if Result.Code = Podmander.Messages.Result_Codes.Ok then
         Podmander.Logging.Info
           ("controller",
            "Deploy succeeded for " & To_String (Result.Service_Name));
      else
         Podmander.Logging.Warning
           ("controller",
            "Deploy failed for " & To_String (Result.Service_Name)
            & ": " & To_String (Result.Error_Message));
      end if;
   end Handle_Deploy_Result;

   overriding procedure Handle_Status_Query
     (H : in out Controller_Handler;
      M : Podmander.Messages.Status_Query_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("controller", "Status_Query is controller-to-agent only");
   end Handle_Status_Query;

   overriding procedure Handle_Status_Response
     (H : in out Controller_Handler;
      M : Podmander.Messages.Status_Response_Type'Class)
   is
      use type Podmander.Messages.Result_Codes.Result_Code;
      use Podmander.Messages.Status_Responses;
      Resp : constant Status_Response := Status_Response (M);
   begin
      if Resp.Code = Podmander.Messages.Result_Codes.Ok then
         Podmander.Logging.Info
           ("controller", "Agent status: "
            & To_String (Resp.Containers));
      else
         Podmander.Logging.Warning
           ("controller", "Agent status query "
            & Podmander.Messages.Result_Codes.Encode_Code (Resp.Code)
            & ": " & To_String (Resp.Error_Message));
      end if;
   end Handle_Status_Response;

end Podmander.Controller.Message_Handlers;
