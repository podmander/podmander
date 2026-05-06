--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Text_IO;
with CZMQ.Messages;
with GNAT.OS_Lib;
with Podmander.Logging;
with Podmander.Messages.Deploy_Commands;

package body Podmander.Agent.Message_Handlers is

   LF : constant Character := Character'Val (10);

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
      use Podmander.Messages.Deploy_Results;
      Cmd       : constant Deploy_Command := Deploy_Command (M);
      Name      : constant String := To_String (Cmd.Service_Name);
      Content   : constant String := To_String (Cmd.Quadlet);
      Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME");
      Base_Dir  : constant String :=
        Home & "/.config/containers/systemd";
      File_Path : constant String :=
        Base_Dir & "/" & Name & ".container";
      Result    : Deploy_Result;
   begin
      Result.Service_Name := Cmd.Service_Name;

      Podmander.Logging.Info
        ("agent", "Deploying " & Name);

      Ada.Directories.Create_Path (Base_Dir);

      Write_Quadlet :
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (File, Ada.Text_IO.Out_File, File_Path);
         Ada.Text_IO.Put (File, Content);
         Ada.Text_IO.Close (File);
      end Write_Quadlet;

      Daemon_Reload :
      declare
         Args    : GNAT.OS_Lib.Argument_List (1 .. 2);
         Success : Boolean;
      begin
         Args (1) := new String'("--user");
         Args (2) := new String'("daemon-reload");
         GNAT.OS_Lib.Spawn
           ("/usr/bin/systemctl", Args, Success);
         for J in Args'Range loop
            GNAT.OS_Lib.Free (Args (J));
         end loop;
         if not Success then
            Result.Success := False;
            Result.Error_Message :=
              To_Unbounded_String ("daemon-reload failed");
            Podmander.Logging.Error
              ("agent", "daemon-reload failed for " & Name);
            Send_Deploy_Result (H, Result);
            return;
         end if;
      end Daemon_Reload;

      Start_Service :
      declare
         Args    : GNAT.OS_Lib.Argument_List (1 .. 3);
         Success : Boolean;
      begin
         Args (1) := new String'("--user");
         Args (2) := new String'("start");
         Args (3) := new String'(Name & ".service");
         GNAT.OS_Lib.Spawn
           ("/usr/bin/systemctl", Args, Success);
         for J in Args'Range loop
            GNAT.OS_Lib.Free (Args (J));
         end loop;
         if not Success then
            Result.Success := False;
            Result.Error_Message :=
              To_Unbounded_String ("systemctl start failed");
            Podmander.Logging.Error
              ("agent", "systemctl start failed for " & Name);
            Send_Deploy_Result (H, Result);
            return;
         end if;
      end Start_Service;

      Result.Success := True;
      Result.Error_Message := To_Unbounded_String ("");
      Podmander.Logging.Info
        ("agent", "Deployed " & Name & " successfully");
      Send_Deploy_Result (H, Result);
   exception
      when E : others =>
         Result.Success := False;
         Result.Error_Message := To_Unbounded_String
           (Ada.Exceptions.Exception_Message (E));
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
      use Podmander.Messages.Status_Responses;
      Shell_Args : GNAT.OS_Lib.Argument_List (1 .. 2);
      Success    : Boolean;
      Temp_Path  : constant String := "/tmp/podmander-status.txt";
      Result     : Status_Response;
   begin
      Shell_Args (1) := new String'("-c");
      Shell_Args (2) := new String'
        ("/usr/bin/podman ps --format "
         & "'{{.Names}} {{.Status}}' > "
         & Temp_Path & " 2>/dev/null");
      GNAT.OS_Lib.Spawn ("/bin/sh", Shell_Args, Success);
      for J in Shell_Args'Range loop
         GNAT.OS_Lib.Free (Shell_Args (J));
      end loop;

      if Success and then Ada.Directories.Exists (Temp_Path) then
         declare
            File    : Ada.Text_IO.File_Type;
            Content : Unbounded_String := To_Unbounded_String ("");
         begin
            Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Temp_Path);
            while not Ada.Text_IO.End_Of_File (File) loop
               if Length (Content) > 0 then
                  Append (Content, LF);
               end if;
               Append (Content, Ada.Text_IO.Get_Line (File));
            end loop;
            Ada.Text_IO.Close (File);
            Result.Containers := Content;
         end;
         Ada.Directories.Delete_File (Temp_Path);
      else
         Result.Containers := To_Unbounded_String ("");
      end if;

      Podmander.Logging.Info
        ("agent", "Status query: sending container list");
      Send_Status_Response (H, Result);
   exception
      when E : others =>
         Result.Containers := To_Unbounded_String
           ("error: " & Ada.Exceptions.Exception_Message (E));
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
