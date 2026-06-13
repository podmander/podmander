--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Calendar;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Control_Channel;
with Podmander.Controller.Node.Repository;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Types;
with Podmander.Database;
with Podmander.Enrollment;
with Podmander.Logging;
with Podmander.Messages.Deployment_Results;
with Podmander.Messages.Registration_Requests;
with Podmander.Messages.Registration_Responses;
with Podmander.Messages.Heartbeats;
with Podmander.Messages.Result_Codes;
with Podmander.Messages.Status_Queries;
with Podmander.Messages.Status_Responses;
with Podmander.Messages.Stack_Submissions;
with Podmander.Messages.Stack_Submission_Results;
with Podmander.Controller.Stack_Submission;

package body Podmander.Controller.Message_Handlers is

   use Podmander.Types;
   use type Podmander.Database.Error_Kind;

   --  Send a reply to a connection identity through a transiently wrapped
   --  Control Channel, which borrows the controller's socket. No-op when that
   --  socket is not open -- the seam that lets handler logic run in tests
   --  without a live socket, in place of an Is_Valid guard at each call site.
   procedure Send_Reply
     (H        : Controller_Handler;
      Identity : String;
      Message  : Podmander.Messages.Protocol_Message'Class) is
   begin
      Control_Channel.Wrap (H.Ctrl.Socket'Unchecked_Access).Send
        (Identity, Message);
   end Send_Reply;

   procedure Send_Status_Query
     (H : in out Controller_Handler; Connection_Id : String)
   is
      use Podmander.Messages.Status_Queries;
      Query : constant Status_Query := (null record);
   begin
      Send_Reply (H, Connection_Id, Query);
      Podmander.Logging.Info
        ("controller", "Sent status query to " & Connection_Id);
   end Send_Status_Query;

   overriding
   procedure Handle_Registration_Request
     (H : in out Controller_Handler;
      M : Podmander.Messages.Registration_Request_Type'Class)
   is
      use Podmander.Messages.Registration_Requests;
      use Podmander.Messages.Registration_Responses;
      Req           : constant Registration_Request :=
        Registration_Request (M);
      Name          : constant String := To_String (Req.Agent_Name);
      Connection_Id : constant String := To_String (H.Identity);
   begin
      if not Podmander.Enrollment.Secret_Matches
               (H.Ctrl.Config.Enrollment, To_String (Req.Enrollment_Secret))
      then
         Podmander.Logging.Error
           ("controller",
            "Invalid enrollment secret from agent """ & Name & """");
         return;
      end if;

      declare
         Node_Id : constant Node_Id_Type :=
           Node.Repository.Create_Or_Get (H.Ctrl.DB, Name);
         Info    : constant Podmander.Types.Agent_Info :=
           (Id            => 0,
            Name          => Req.Agent_Name,
            Connection_Id => To_Unbounded_String (Connection_Id),
            State         => Podmander.Types.Registered,
            Last_Seen     => Ada.Calendar.Clock,
            Node_Id       => Node_Id);
      begin
         -- Persist to DB
         begin
            Agent.Repository.Register (H.Ctrl.DB, Info);
         exception
            when E : Podmander.Database.Database_Error =>
               if Podmander.Database.Parse_Error (E).Kind
                 = Podmander.Database.Constraint_Violation
               then
                  -- Agent already in DB (re-registration after restart).
                  -- Update instead of insert.
                  Agent.Repository.Touch (H.Ctrl.DB, Info);
                  Agent.Repository.Set_State (H.Ctrl.DB, Info);
               else
                  raise;
               end if;
         end;
         Podmander.Logging.Info
           ("controller",
            "Registered agent """ & Name & """ as " & Connection_Id);
      end;

      declare
         Reply : constant Registration_Response :=
           (Connection_Id => To_Unbounded_String (Connection_Id));
      begin
         Send_Reply (H, Connection_Id, Reply);
      end;

      Send_Status_Query (H, Connection_Id);
   end Handle_Registration_Request;

   overriding
   procedure Handle_Heartbeat
     (H : in out Controller_Handler;
      M : Podmander.Messages.Heartbeat_Message_Type'Class)
   is
      use Podmander.Controller.Service_Catalog.Repository;
      use Podmander.Messages.Heartbeats;
      HB            : constant Heartbeat_Message := Heartbeat_Message (M);
      Connection_Id : constant String := To_String (HB.Connection_Id);
      Found         : Boolean := False;
      All_Agents    : constant Podmander.Types.Agent_Maps.Map :=
        Agent.Repository.Load_All (H.Ctrl.DB);
   begin
      -- The map is keyed by agent name, not by Connection_Id, so we must
      -- scan linearly to find the agent with the matching Connection_Id.
      for Cur in All_Agents.Iterate loop
         declare
            Info : Podmander.Types.Agent_Info :=
              Podmander.Types.Agent_Maps.Element (Cur);
         begin
            if To_String (Info.Connection_Id) = Connection_Id then
               Found := True;
               Info.Last_Seen := Ada.Calendar.Clock;
               if Info.State /= Podmander.Types.Registered then
                  Info.State := Podmander.Types.Registered;
                  Agent.Repository.Set_State (H.Ctrl.DB, Info);
                  --  Reset any In_Progress deploys for this node so they
                  --  are retried now that the agent is connected again.
                  Reset_In_Progress_For_Node (H.Ctrl.DB, Info.Node_Id);
                  Podmander.Logging.Info
                    ("controller", "Agent " & Connection_Id & " reconnected");
               end if;
               Agent.Repository.Touch (H.Ctrl.DB, Info);
               Podmander.Logging.Debug
                 ("controller", "Heartbeat from " & Connection_Id);
               exit;
            end if;
         end;
      end loop;

      if not Found then
         Podmander.Logging.Warning
           ("controller",
            "Heartbeat from unregistered agent "
            & To_String (H.Identity)
            & ", ignoring");
      end if;
   end Handle_Heartbeat;

   overriding
   procedure Handle_Deployment_Command
     (H : in out Controller_Handler;
      M : Podmander.Messages.Deployment_Command_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("controller", "Deployment_Command is controller-to-agent only");
   end Handle_Deployment_Command;

   overriding
   procedure Handle_Deployment_Result
     (H : in out Controller_Handler;
      M : Podmander.Messages.Deployment_Result_Type'Class)
   is
      use Podmander.Messages.Deployment_Results;
      use type Podmander.Messages.Result_Codes.Result_Code;
      Result : constant Deployment_Result := Deployment_Result (M);
   begin
      if Result.Catalog_Id > 0 then
         -- Catalog-based deploy: update the catalog entry
         if Result.Code = Podmander.Messages.Result_Codes.Ok then
            declare
               use Podmander.Controller.Service_Catalog.Repository;
               Cat_Entry :
                 constant Podmander.Controller.Service_Catalog_Entry :=
                   Get_By_Id (H.Ctrl.DB, Result.Catalog_Id);
               Ok        : constant Boolean :=
                 Update_On_Success
                   (H.Ctrl.DB, Cat_Entry.Id, Cat_Entry.Target_Version);
               pragma Unreferenced (Ok);
            begin
               Podmander.Logging.Info
                 ("controller",
                  "Deploy succeeded for "
                  & To_String (Result.Service_Name)
                  & " (catalog "
                  & Result.Catalog_Id'Image
                  & ")");
            end;
         else
            declare
               use Podmander.Controller.Service_Catalog.Repository;
               Ok : constant Boolean :=
                 Update_On_Failure (H.Ctrl.DB, Result.Catalog_Id);
               pragma Unreferenced (Ok);
            begin
               Podmander.Logging.Warning
                 ("controller",
                  "Deploy failed for "
                  & To_String (Result.Service_Name)
                  & " (catalog "
                  & Result.Catalog_Id'Image
                  & "): "
                  & To_String (Result.Error_Message));
            end;
         end if;
      else
         -- Legacy path (catalog_id = 0): just log
         if Result.Code = Podmander.Messages.Result_Codes.Ok then
            Podmander.Logging.Info
              ("controller",
               "Deploy succeeded for " & To_String (Result.Service_Name));
         else
            Podmander.Logging.Warning
              ("controller",
               "Deploy failed for "
               & To_String (Result.Service_Name)
               & ": "
               & To_String (Result.Error_Message));
         end if;
      end if;
   end Handle_Deployment_Result;

   overriding
   procedure Handle_Status_Query
     (H : in out Controller_Handler;
      M : Podmander.Messages.Status_Query_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("controller", "Status_Query is controller-to-agent only");
   end Handle_Status_Query;

   overriding
   procedure Handle_Status_Response
     (H : in out Controller_Handler;
      M : Podmander.Messages.Status_Response_Type'Class)
   is
      use type Podmander.Messages.Result_Codes.Result_Code;
      use Podmander.Messages.Status_Responses;
      Resp : constant Status_Response := Status_Response (M);
   begin
      if Resp.Code = Podmander.Messages.Result_Codes.Ok then
         Podmander.Logging.Info
           ("controller", "Agent status: " & To_String (Resp.Containers));
      else
         Podmander.Logging.Warning
           ("controller",
            "Agent status query "
            & Podmander.Messages.Result_Codes.Encode_Code (Resp.Code)
            & ": "
            & To_String (Resp.Error_Message));
      end if;
   end Handle_Status_Response;

   overriding
   procedure Handle_Stack_Submission
     (H : in out Controller_Handler;
      M : Podmander.Messages.Stack_Submission_Type'Class)
   is
      use Podmander.Messages.Stack_Submissions;
      Cmd : constant Podmander.Messages.Stack_Submissions.Stack_Submission :=
        Podmander.Messages.Stack_Submissions.Stack_Submission (M);
   begin
      if not Podmander.Enrollment.Secret_Matches
               (H.Ctrl.Config.Enrollment, To_String (Cmd.Enrollment_Secret))
      then
         Podmander.Logging.Error
           ("controller", "Invalid enrollment secret in Stack_Submission");
         Send_Stack_Submission_Result
           (H,
            Success  => False,
            Message  => "Invalid enrollment secret",
            Identity => To_String (H.Identity));
         return;
      end if;

      declare
         Submission_Res :
           constant Podmander.Controller.Stack_Submission.Submission_Result :=
             Podmander.Controller.Stack_Submission.Submit
               (H.Ctrl.DB, To_String (Cmd.TOML));
      begin
         Send_Stack_Submission_Result
           (H,
            Success  => Submission_Res.Ok,
            Message  => To_String (Submission_Res.Message),
            Identity => To_String (H.Identity));
      end;
   end Handle_Stack_Submission;

   overriding
   procedure Handle_Stack_Submission_Result
     (H : in out Controller_Handler;
      M : Podmander.Messages.Stack_Submission_Result_Type'Class)
   is
      pragma Unreferenced (H, M);
   begin
      Podmander.Logging.Warning
        ("controller",
         "Stack_Submission_Result is controller-to-operator only");
   end Handle_Stack_Submission_Result;

   procedure Send_Stack_Submission_Result
     (H        : in out Controller_Handler;
      Success  : Boolean;
      Message  : String;
      Identity : String)
   is
      use Podmander.Messages.Stack_Submission_Results;
      Result_Msg : constant Stack_Submission_Result :=
        (Success => Success, Message => To_Unbounded_String (Message));
   begin
      Send_Reply (H, Identity, Result_Msg);
      Podmander.Logging.Info
        ("controller",
         "Sent Stack_Submission_Result to "
         & Identity
         & (if Success then " (success)" else " (failure)"));
   end Send_Stack_Submission_Result;

end Podmander.Controller.Message_Handlers;
