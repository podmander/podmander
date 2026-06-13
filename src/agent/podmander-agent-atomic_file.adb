--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Text_IO;
with GNAT.OS_Lib;

package body Podmander.Agent.Atomic_File is

   procedure Write (Path : String; Content : String) is
      Tmp_Path  : constant String := Path & ".tmp";
      File      : Ada.Text_IO.File_Type;
      Rename_OK : Boolean;
   begin
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp_Path);
         Ada.Text_IO.Put (File, Content);
         Ada.Text_IO.Close (File);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            if Ada.Directories.Exists (Tmp_Path) then
               declare
                  Deleted : Boolean;
               begin
                  GNAT.OS_Lib.Delete_File (Tmp_Path, Deleted);
               end;
            end if;
            raise;
      end;
      GNAT.OS_Lib.Rename_File (Tmp_Path, Path, Rename_OK);
      if not Rename_OK then
         declare
            Deleted : Boolean;
         begin
            GNAT.OS_Lib.Delete_File (Tmp_Path, Deleted);
         end;
         raise Ada.IO_Exceptions.Use_Error
           with "rename to " & Path & " failed";
      end if;
   end Write;

end Podmander.Agent.Atomic_File;
