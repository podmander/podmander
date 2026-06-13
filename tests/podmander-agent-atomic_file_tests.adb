--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Agent.Atomic_File;

package body Podmander.Agent.Atomic_File_Tests is

   use AUnit.Assertions;

   type Atomic_File_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Atomic_File_Test) return AUnit.Message_String
   is (AUnit.Format ("Agent.Atomic_File"));

   overriding
   procedure Register_Tests (T : in out Atomic_File_Test);

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Strings.Unbounded.Append (Content, Ada.Text_IO.Get_Line (File));
         if not Ada.Text_IO.End_Of_File (File) then
            Ada.Strings.Unbounded.Append
              (Content,
               Ada.Strings.Unbounded.To_Unbounded_String ("" & ASCII.LF));
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Content);
   end Read_File;

   --  Write creates the target with the exact content and leaves no .tmp.
   procedure Test_Write_Creates_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Test_Dir  : constant String := "test_atomic_file_create";
      File_Path : constant String := Test_Dir & "/target.txt";
      Tmp_Path  : constant String := File_Path & ".tmp";
      Content   : constant String := "quadlet content";
   begin
      if Ada.Directories.Exists (Test_Dir) then
         Ada.Directories.Delete_Tree (Test_Dir);
      end if;
      Ada.Directories.Create_Directory (Test_Dir);
      Podmander.Agent.Atomic_File.Write (File_Path, Content);
      Assert (Ada.Directories.Exists (File_Path), "Target file must exist");
      Assert
        (not Ada.Directories.Exists (Tmp_Path), "No .tmp file must remain");
      Assert (Read_File (File_Path) = Content, "File content must match");
      Ada.Directories.Delete_File (File_Path);
      Ada.Directories.Delete_Directory (Test_Dir);
   end Test_Write_Creates_File;

   --  Write overwrites an existing target (regression guard: Ada.Directories.Rename
   --  raises USE_ERROR on overwrite; GNAT.OS_Lib.Rename_File must be used instead).
   procedure Test_Write_Overwrites_Existing
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Test_Dir     : constant String := "test_atomic_file_overwrite";
      File_Path    : constant String := Test_Dir & "/target.txt";
      Tmp_Path     : constant String := File_Path & ".tmp";
      Old_Content  : constant String := "original content";
      New_Content  : constant String := "updated content";
      Initial_File : Ada.Text_IO.File_Type;
   begin
      if Ada.Directories.Exists (Test_Dir) then
         Ada.Directories.Delete_Tree (Test_Dir);
      end if;
      Ada.Directories.Create_Directory (Test_Dir);
      Ada.Text_IO.Create (Initial_File, Ada.Text_IO.Out_File, File_Path);
      Ada.Text_IO.Put (Initial_File, Old_Content);
      Ada.Text_IO.Close (Initial_File);
      Podmander.Agent.Atomic_File.Write (File_Path, New_Content);
      Assert (Ada.Directories.Exists (File_Path), "Target file must exist");
      Assert
        (not Ada.Directories.Exists (Tmp_Path), "No .tmp file must remain");
      Assert
        (Read_File (File_Path) = New_Content, "File must contain new content");
      Ada.Directories.Delete_File (File_Path);
      Ada.Directories.Delete_Directory (Test_Dir);
   end Test_Write_Overwrites_Existing;

   --  A write into a non-existent directory must raise and leave no partial
   --  file at the target path and no .tmp sibling.
   procedure Test_Write_Fails_Without_Directory
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Missing_Dir : constant String := "test_atomic_file_missing_dir";
      File_Path   : constant String := Missing_Dir & "/target.txt";
      Tmp_Path    : constant String := File_Path & ".tmp";
      Raised      : Boolean := False;
   begin
      if Ada.Directories.Exists (Missing_Dir) then
         Ada.Directories.Delete_Tree (Missing_Dir);
      end if;
      Assert
        (not Ada.Directories.Exists (Missing_Dir),
         "Precondition: parent directory absent");
      begin
         Podmander.Agent.Atomic_File.Write (File_Path, "content");
      exception
         when others =>
            Raised := True;
      end;
      Assert (Raised, "Write must raise when directory does not exist");
      Assert
        (not Ada.Directories.Exists (File_Path),
         "No target file must exist after failed write");
      Assert
        (not Ada.Directories.Exists (Tmp_Path),
         "No .tmp must exist after failed write");
   end Test_Write_Fails_Without_Directory;

   overriding
   procedure Register_Tests (T : in out Atomic_File_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Write_Creates_File'Access, "Write creates file with content");
      Register_Routine
        (T,
         Test_Write_Overwrites_Existing'Access,
         "Write overwrites existing target atomically");
      Register_Routine
        (T,
         Test_Write_Fails_Without_Directory'Access,
         "Write raises and leaves no file when directory absent");
   end Register_Tests;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, new Atomic_File_Test);
      return Result;
   end Suite;

end Podmander.Agent.Atomic_File_Tests;
