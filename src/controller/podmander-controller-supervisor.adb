--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.Controller.Agent.Repository;
with Podmander.Controller.Scheduler;
with Podmander.Controller.Service.Repository;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Controller.Strategies.First_Available;
with Podmander.Generators.Quadlet;
with Podmander.Logging;
with Podmander.Messages.Deployment_Commands;
with Podmander.Types;

package body Podmander.Controller.Supervisor is

   use Ada.Strings.Unbounded;
   use Podmander.Types;

   --  Convert a Service_Version plus its name into a Service_Definition.
   function To_Service_Definition
     (SV : Service_Version; Name : String) return Service_Definition is
   begin
      return
        (Service_Name  => To_Unbounded_String (Name),
         Image         => SV.Image,
         Env           => SV.Env,
         Env_Count     => SV.Env_Count,
         Ports         => SV.Ports,
         Ports_Count   => SV.Ports_Count,
         Volumes       => SV.Volumes,
         Volumes_Count => SV.Volumes_Count,
         Description   => SV.Description,
         WantedBy      => SV.Wanted_By);
   end To_Service_Definition;

   --  Send a Deployment_Command to the agent identified by Cat_Entry's assigned
   --  node. Does nothing if no node is assigned or no Registered agent serves
   --  that node.
   procedure Try_Deploy_Entry
     (DB        : in out Podmander.Database.DB_Handle;
      Chan      : in out Control_Channel.Channel;
      Cat_Entry : Service_Catalog_Entry)
   is
      use Podmander.Controller.Service_Catalog.Repository;
      use Podmander.Messages.Deployment_Commands;
      All_Agents          : constant Podmander.Types.Agent_Maps.Map :=
        Agent.Repository.Load_All (DB);
      Agent_Found         : Boolean := False;
      Agent_Connection_Id : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Cat_Entry.Assigned_Node.Present then
         return;
      end if;

      for Cur in All_Agents.Iterate loop
         declare
            Info : constant Podmander.Types.Agent_Info :=
              Podmander.Types.Agent_Maps.Element (Cur);
         begin
            if Info.Node_Id = Cat_Entry.Assigned_Node.Node_Id
              and then Info.State = Podmander.Types.Registered
            then
               Agent_Found := True;
               Agent_Connection_Id := Info.Connection_Id;
               exit;
            end if;
         end;
      end loop;

      if not Agent_Found then
         return;
      end if;

      declare
         SV           : constant Service_Version :=
           Service.Repository.Get_Version
             (DB, Cat_Entry.Service_Id, Cat_Entry.Target_Version);
         SD           : constant Service_Definition :=
           To_Service_Definition (SV, "");
         Svc          : constant Podmander.Controller.Service.Service :=
           Service.Repository.Get_By_Id (DB, Cat_Entry.Service_Id);
         SD_With_Name : constant Service_Definition :=
           (Service_Name  => Svc.Name,
            Image         => SD.Image,
            Env           => SD.Env,
            Env_Count     => SD.Env_Count,
            Ports         => SD.Ports,
            Ports_Count   => SD.Ports_Count,
            Volumes       => SD.Volumes,
            Volumes_Count => SD.Volumes_Count,
            Description   => SD.Description,
            WantedBy      => SD.WantedBy);
         Quadlet      : constant String :=
           Podmander.Generators.Quadlet.Render (SD_With_Name);
         Cmd          : constant Deployment_Command :=
           (Catalog_Id   => Cat_Entry.Id,
            Service_Name => Svc.Name,
            Quadlet      => To_Unbounded_String (Quadlet));
      begin
         Chan.Send (To_String (Agent_Connection_Id), Cmd);
         declare
            Set_State_Ok : constant Boolean :=
              Set_State (DB, Cat_Entry.Id, In_Progress);
            pragma Unreferenced (Set_State_Ok);
         begin
            null;
         end;
         Podmander.Logging.Info
           ("supervisor",
            "Deploying "
            & To_String (Svc.Name)
            & " v"
            & Cat_Entry.Target_Version'Image
            & " to "
            & To_String (Agent_Connection_Id)
            & " (catalog "
            & Cat_Entry.Id'Image
            & ")");
      end;
   end Try_Deploy_Entry;

   --  Schedule all catalog entries that have no assigned node, using the
   --  First_Available strategy.
   procedure Schedule_Unscheduled (DB : in out Podmander.Database.DB_Handle) is
      use Podmander.Controller.Service_Catalog.Repository;
      Unscheduled : constant Catalog_Entry_Vectors.Vector :=
        Get_Unscheduled (DB);
   begin
      for Cursor in Unscheduled.Iterate loop
         declare
            Cat_Entry : constant Service_Catalog_Entry :=
              Catalog_Entry_Vectors.Element (Cursor);
            Result    : constant Scheduler.Schedule_Result :=
              Scheduler.Schedule
                (DB,
                 Cat_Entry.Service_Id,
                 Cat_Entry.Target_Version,
                 Podmander.Controller.Strategies.First_Available.Instance);
         begin
            if Result.Ok and then Result.Catalog_Entry.Assigned_Node.Present
            then
               Podmander.Logging.Info
                 ("supervisor",
                  "Scheduled catalog entry "
                  & Cat_Entry.Id'Image
                  & " to node "
                  & Result.Catalog_Entry.Assigned_Node.Node_Id'Image);
            end if;
         end;
      end loop;
   end Schedule_Unscheduled;

   --  Attempt to deploy all Pending catalog entries that have an assigned node
   --  and a Registered agent.
   procedure Deploy_Pending
     (DB   : in out Podmander.Database.DB_Handle;
      Chan : in out Control_Channel.Channel)
   is
      use Podmander.Controller.Service_Catalog.Repository;
      Pending_Entries : constant Catalog_Entry_Vectors.Vector :=
        Get_Pending (DB);
   begin
      for Cursor in Pending_Entries.Iterate loop
         Try_Deploy_Entry (DB, Chan, Catalog_Entry_Vectors.Element (Cursor));
      end loop;
   end Deploy_Pending;

   procedure Tick
     (DB   : in out Podmander.Database.DB_Handle;
      Chan : in out Control_Channel.Channel) is
   begin
      Schedule_Unscheduled (DB);
      Deploy_Pending (DB, Chan);
   end Tick;

   procedure Recover (DB : in out Podmander.Database.DB_Handle) is
   begin
      Podmander.Controller.Service_Catalog.Repository.Reset_In_Progress (DB);
   end Recover;

end Podmander.Controller.Supervisor;
