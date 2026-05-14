--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Podmander.Generators.Quadlet is

   use Ada.Strings.Unbounded;

   ------------
   --  Render  --
   ------------

   function Render (Service : Service_Definition) return String is
      Buffer : Unbounded_String := Null_Unbounded_String;
   begin
      --  [Unit] section (only if Description is non-empty)
      if Length (Service.Description) > 0 then
         Append (Buffer, "[Unit]" & ASCII.LF);
         Append (Buffer, "Description=" & Service.Description & ASCII.LF);
      end if;

      --  [Container] section header
      Append (Buffer, "[Container]" & ASCII.LF);

      --  ContainerImage is always required
      Append (Buffer, "ContainerImage=" & Service.Image & ASCII.LF);

      --  Environment variables
      for I in 1 .. Service.Env_Count loop
         Append (Buffer, "Environment=");
         Append (Buffer, Service.Env (I).Key);
         Append (Buffer, "=");
         Append (Buffer, Service.Env (I).Value);
         Append (Buffer, ASCII.LF);
      end loop;

      --  Port mappings
      for I in 1 .. Service.Ports_Count loop
         declare
            Host_Image      : constant String :=
              Positive'Image (Service.Ports (I).Host);
            Container_Image : constant String :=
              Positive'Image (Service.Ports (I).Container);
         begin
            --  Positive'Image includes a leading space; strip it
            Append (Buffer, "PublishPort=");
            Append (Buffer, Host_Image (2 .. Host_Image'Last));
            Append (Buffer, ":");
            Append (Buffer, Container_Image (2 .. Container_Image'Last));
            Append (Buffer, ASCII.LF);
         end;
      end loop;

      --  Volume mappings
      for I in 1 .. Service.Volumes_Count loop
         Append (Buffer, "Volume=");
         Append (Buffer, Service.Volumes (I).Host);
         Append (Buffer, ":");
         Append (Buffer, Service.Volumes (I).Container);
         Append (Buffer, ASCII.LF);
      end loop;

      --  [Install] section
      Append (Buffer, "[Install]" & ASCII.LF);
      if Length (Service.WantedBy) > 0 then
         Append (Buffer, "WantedBy=" & Service.WantedBy & ASCII.LF);
      else
         Append (Buffer, "WantedBy=multi-user.target" & ASCII.LF);
      end if;

      return To_String (Buffer);
   end Render;

   -----------------
   --  Write_File  --
   -----------------

   procedure Write_File
     (Service      : Service_Definition;
      Output_Dir   : String;
      Service_Name : String)
   is
      File_Path : constant String :=
        Output_Dir & "/" & Service_Name & ".container";
      Content   : constant String := Render (Service);
      File      : Ada.Text_IO.File_Type;
   begin
      Ada.Directories.Create_Path (Output_Dir);
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, File_Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   end Write_File;

end Podmander.Generators.Quadlet;
