--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with CZMQ.Messages;
with Podmander.Enrollment;
with Podmander.Logging;
with Podmander.Messages.Register_Requests;
with Podmander.Messages.Register_Responses;
with Podmander.Messages.Heartbeats;

package body Podmander.Controller.Message_Handlers is

   overriding procedure Handle_Register_Request
     (H : in out Controller_Handler;
      M : Podmander.Messages.Register_Request_Type'Class)
   is
      use Podmander.Messages.Register_Requests;
      use Podmander.Messages.Register_Responses;
      Req     : constant Register_Request := Register_Request (M);
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

      if H.Ctrl.Socket /= null then
         declare
            Reply     : constant Register_Response :=
              (Node_Id => To_Unbounded_String (Node_Id));
            Reply_Msg : CZMQ.Messages.Message :=
              CZMQ.Messages.New_Message;
         begin
            Reply_Msg.Add_String (Node_Id);
            Reply.Encode (Reply_Msg);
            Reply_Msg.Send (H.Ctrl.Socket.all);
         end;
      end if;
   end Handle_Register_Request;

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

end Podmander.Controller.Message_Handlers;
