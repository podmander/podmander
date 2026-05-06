--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Podmander.Logging;

package body Podmander.Agent.Status_Collector is

   use Ada.Strings.Unbounded;
   use Podmander.Messages.Status_Responses;

   LF : constant Character := Character'Val (10);

   function Collect_Status
      return Status_Response
   is
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
      return Result;
   exception
      when E : others =>
         Result.Containers := To_Unbounded_String
           ("error: " & Ada.Exceptions.Exception_Message (E));
         return Result;
   end Collect_Status;

end Podmander.Agent.Status_Collector;
