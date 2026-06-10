--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Podmander.Controller.Node.Repository;
with Podmander.Database;

package body Podmander.Controller.Node.Repository_Tests is

   use AUnit.Assertions;

   package DB renames Podmander.Database;
   package Repo renames Podmander.Controller.Node.Repository;

   use type DB.Error_Kind;

   type Node_Repo_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Node_Repo_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Node.Repository"));

   overriding
   procedure Register_Tests (T : in out Node_Repo_Test);

   --  Create_Or_Get inserts a new node and returns its id
   procedure Test_Create_Or_Get_New_Node (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D : DB.DB_Handle := DB.Open (":memory:");
      Node_Id : constant Integer := Repo.Create_Or_Get (D, "worker-01");
   begin
      Assert (Node_Id > 0, "Create_Or_Get should return a positive id for new node");
   end Test_Create_Or_Get_New_Node;

   --  Create_Or_Get returns existing id when called with same name
   procedure Test_Create_Or_Get_Idempotent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Id_First  : constant Integer := Repo.Create_Or_Get (D, "worker-02");
      Id_Second : constant Integer := Repo.Create_Or_Get (D, "worker-02");
   begin
      Assert (Id_First = Id_Second, "Create_Or_Get should return same id for same name");
   end Test_Create_Or_Get_Idempotent;

   --  Create_Or_Get returns different ids for different names
   procedure Test_Create_Or_Get_Different_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D        : DB.DB_Handle := DB.Open (":memory:");
      Id_Alpha : constant Integer := Repo.Create_Or_Get (D, "alpha");
      Id_Beta  : constant Integer := Repo.Create_Or_Get (D, "beta");
   begin
      Assert (Id_Alpha /= Id_Beta, "Create_Or_Get should return different ids for different names");
      Assert (Id_Alpha > 0, "Alpha id should be positive");
      Assert (Id_Beta > 0, "Beta id should be positive");
   end Test_Create_Or_Get_Different_Names;

   --  Load_By_Name returns the id of an existing node
   procedure Test_Load_By_Name_Existing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D        : DB.DB_Handle := DB.Open (":memory:");
      Created_Id : constant Integer := Repo.Create_Or_Get (D, "worker-03");
      Loaded_Id  : constant Integer := Repo.Load_By_Name (D, "worker-03");
   begin
      Assert (Loaded_Id = Created_Id, "Load_By_Name should return the same id as Create_Or_Get");
   end Test_Load_By_Name_Existing;

   --  Load_By_Name raises Not_Found for nonexistent node
   procedure Test_Load_By_Name_Not_Found (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      Got_Error : Boolean := False;
   begin
      begin
         declare
            Id : constant Integer := Repo.Load_By_Name (D, "nonexistent");
            pragma Unreferenced (Id);
         begin
            null;
         end;
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert (Err.Kind = DB.Not_Found, "Load_By_Name should raise Not_Found for missing node");
               Got_Error := True;
            end;
      end;
      Assert (Got_Error, "Load_By_Name should have raised Database_Error for missing node");
   end Test_Load_By_Name_Not_Found;

   --  Register all test routines
   overriding
   procedure Register_Tests (T : in out Node_Repo_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Create_Or_Get_New_Node'Access, "Create_Or_Get creates a new node and returns its id");
      Register_Routine
        (T, Test_Create_Or_Get_Idempotent'Access, "Create_Or_Get returns same id for same name");
      Register_Routine
        (T, Test_Create_Or_Get_Different_Names'Access, "Create_Or_Get returns different ids for different names");
      Register_Routine
        (T, Test_Load_By_Name_Existing'Access, "Load_By_Name returns id of existing node");
      Register_Routine
        (T, Test_Load_By_Name_Not_Found'Access, "Load_By_Name raises Not_Found for nonexistent node");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Node_Repo_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Node.Repository_Tests;