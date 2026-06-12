--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with AUnit.Assertions;
with AUnit.Test_Cases;
with Ada.Calendar;
with Ada.Strings.Unbounded;
with Podmander.Controller.Node.Repository;
with Podmander.Controller.Service_Catalog.Repository;
with Podmander.Controller.Service.Repository;
with Podmander.Database;
with Podmander.Types;

package body Podmander.Controller.Service_Catalog.Repository_Tests is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Podmander.Types;

   package DB renames Podmander.Database;
   package Svc_Repo renames Podmander.Controller.Service.Repository;
   package Node_Repo renames Podmander.Controller.Node.Repository;
   package Repo renames Podmander.Controller.Service_Catalog.Repository;

   use type DB.Error_Kind;

   type Repository_Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Repository_Test) return AUnit.Message_String
   is (AUnit.Format ("Podmander.Controller.Service_Catalog.Repository"));

   overriding
   procedure Register_Tests (T : in out Repository_Test);

   -- Helper: create a service and at least one version so FK constraints
   -- are satisfied. Returns the service id.
   function Seed_Service
     (Handle : in out DB.DB_Handle; Name : String; Versions : Positive)
      return Podmander.Controller.Service_Id_Type
   is
      Svc_Rec : constant Podmander.Controller.Service.Service :=
        Svc_Repo.Create (Handle, Name);
      SV      : Podmander.Controller.Service_Version;
   begin
      for V in 1 .. Versions loop
         SV.Id := 0;
         SV.Service_Id := Svc_Rec.Id;
         SV.Version := Podmander.Controller.Service_Version_Type (V);
         SV.Image := To_Unbounded_String ("test:latest");
         SV.Created_At := Ada.Calendar.Clock;
         Svc_Repo.Create_Version (Handle, SV);
      end loop;
      return Svc_Rec.Id;
   end Seed_Service;

   -- Helper: create a node and return its id.
   function Seed_Node
     (Handle : in out DB.DB_Handle; Name : String) return Node_Id_Type is
   begin
      return Node_Repo.Create_Or_Get (Handle, Name);
   end Seed_Node;

   ---------------------
   -- Test_Create_Entry
   ---------------------

   procedure Test_Create_Entry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 2);
      Node    : constant Node_Id_Type := Seed_Node (D, "node-1");
      Cat_Ent : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry
          (D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 2);
   begin
      Assert (Cat_Ent.Id > 0, "Id should be positive after create");
      Assert (Cat_Ent.Service_Id = Svc, "Service_Id should match");
      Assert
        (Cat_Ent.Assigned_Node.Present
         and then Cat_Ent.Assigned_Node.Node_Id = Node,
         "Assigned_Node should match");
      Assert
        (not Cat_Ent.Current_Version.Present,
         "Current_Version should be absent for new entry");
      Assert
        (Cat_Ent.Target_Version
         = Podmander.Controller.Service_Version_Type (2),
         "Target_Version should be 2");
      Assert
        (Cat_Ent.State = Podmander.Controller.Pending,
         "State should be Pending");
   end Test_Create_Entry;

   -------------------------------
   -- Test_Create_Entry_Unscheduled
   -------------------------------

   procedure Test_Create_Entry_Unscheduled
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "db", 1);
      Cat_Ent : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry (D, Service_Id => Svc, Target_Version => 1);
   begin
      Assert (Cat_Ent.Id > 0, "Id should be positive after create");
      Assert
        (not Cat_Ent.Assigned_Node.Present,
         "Assigned_Node should be absent for unscheduled entry");
   end Test_Create_Entry_Unscheduled;

   -----------------
   -- Test_Get_By_Id
   -----------------

   procedure Test_Get_By_Id (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 2);
      Node    : constant Node_Id_Type := Seed_Node (D, "node-1");
      Created : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry
          (D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 2);
      Loaded  : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Get_By_Id (D, Created.Id);
   begin
      Assert (Loaded.Id = Created.Id, "Id should match");
      Assert (Loaded.Service_Id = Svc, "Service_Id should match");
      Assert
        (Loaded.Assigned_Node.Present
         and then Loaded.Assigned_Node.Node_Id = Node,
         "Assigned_Node should match");
      Assert
        (Loaded.Target_Version = Podmander.Controller.Service_Version_Type (2),
         "Target_Version should match");
   end Test_Get_By_Id;

   ---------------------------
   -- Test_Get_By_Id_Not_Found
   ---------------------------

   procedure Test_Get_By_Id_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D         : DB.DB_Handle := DB.Open (":memory:");
      Got_Error : Boolean := False;
   begin
      begin
         declare
            Ignored : Podmander.Controller.Service_Catalog_Entry :=
              Repo.Get_By_Id (D, 999);
         begin
            null;
            pragma Unreferenced (Ignored);
         end;
      exception
         when E : DB.Database_Error =>
            declare
               Err : constant DB.Error_Info := DB.Parse_Error (E);
            begin
               Assert
                 (Err.Kind = DB.Not_Found,
                  "Get_By_Id on unknown should raise Not_Found");
               Got_Error := True;
            end;
      end;
      Assert
        (Got_Error, "Get_By_Id on unknown should have raised Database_Error");
   end Test_Get_By_Id_Not_Found;

   -----------------------
   -- Test_Get_Unscheduled
   -----------------------

   procedure Test_Get_Unscheduled (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D           : DB.DB_Handle := DB.Open (":memory:");
      Svc         : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 1);
      Node        : constant Node_Id_Type := Seed_Node (D, "node-1");
      Ignored1    : Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry
          (D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 1);
      Ignored2    : Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry (D, Service_Id => Svc, Target_Version => 1);
      Unscheduled :
        constant Podmander.Controller.Catalog_Entry_Vectors.Vector :=
          Repo.Get_Unscheduled (D);
   begin
      pragma Unreferenced (Ignored1);
      Assert
        (Natural (Unscheduled.Length) = 1, "Should find 1 unscheduled entry");
      if not Unscheduled.Is_Empty then
         Assert
           (not Unscheduled.First_Element.Assigned_Node.Present,
            "Unscheduled entry should have no node assigned");
      end if;
   end Test_Get_Unscheduled;

   ------------------
   -- Test_Get_Pending
   ------------------

   procedure Test_Get_Pending (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 2);
      Node    : constant Node_Id_Type := Seed_Node (D, "node-1");
      --  Entry with pending deployment: current_version defaults to 0, target is 2
      E       : Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry
          (D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 2);
      Pending : constant Podmander.Controller.Catalog_Entry_Vectors.Vector :=
        Repo.Get_Pending (D);
   begin
      pragma Unreferenced (E);
      Assert (Natural (Pending.Length) = 1, "Should find 1 pending entry");
   end Test_Get_Pending;

   procedure Test_Get_Pending_Excludes_Non_Pending
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 2);
      Node    : constant Node_Id_Type := Seed_Node (D, "node-1");
      E1      : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry
          (D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 2);
      Ignored : Boolean;
      Pending : Podmander.Controller.Catalog_Entry_Vectors.Vector;
   begin
      -- Mark entry as failed
      Ignored := Repo.Update_On_Failure (D, E1.Id);
      pragma Unreferenced (Ignored);
      Pending := Repo.Get_Pending (D);
      Assert
        (Natural (Pending.Length) = 0,
         "Should find 0 pending entries when the only one has failed");
   end Test_Get_Pending_Excludes_Non_Pending;

   --------------------------
   -- Test_Update_On_Success
   --------------------------

   procedure Test_Update_On_Success
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 2);
      Node    : constant Node_Id_Type := Seed_Node (D, "node-1");
      Cat_Ent : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry
          (D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 2);
      Updated : Boolean;
      Loaded  : Podmander.Controller.Service_Catalog_Entry;
   begin
      -- Mark as failed first
      Updated := Repo.Update_On_Failure (D, Cat_Ent.Id);
      Assert (Updated, "Update_On_Failure should return True");

      -- Then mark as success
      Updated :=
        Repo.Update_On_Success
          (D,
           Cat_Ent.Id,
           Current_Version => Podmander.Controller.Service_Version_Type (2));
      Assert (Updated, "Update_On_Success should return True");

      Loaded := Repo.Get_By_Id (D, Cat_Ent.Id);
      Assert
        (Loaded.Current_Version.Present
         and then Loaded.Current_Version.Version
                  = Podmander.Controller.Service_Version_Type (2),
         "Current_Version should be 2 after success");
      Assert
        (Loaded.State = Podmander.Controller.Deployed,
         "State should be Deployed after success");
   end Test_Update_On_Success;

   procedure Test_Update_On_Success_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Updated : Boolean;
   begin
      Updated :=
        Repo.Update_On_Success
          (D,
           999,
           Current_Version => Podmander.Controller.Service_Version_Type (1));
      Assert
        (not Updated, "Update_On_Success should return False for unknown id");
   end Test_Update_On_Success_Not_Found;

   --------------------------
   -- Test_Update_On_Failure
   --------------------------

   procedure Test_Update_On_Failure
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 2);
      Node    : constant Node_Id_Type := Seed_Node (D, "node-1");
      Cat_Ent : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry
          (D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 2);
      Updated : Boolean;
      Loaded  : Podmander.Controller.Service_Catalog_Entry;
   begin
      Updated := Repo.Update_On_Failure (D, Cat_Ent.Id);
      Assert (Updated, "Update_On_Failure should return True");

      Loaded := Repo.Get_By_Id (D, Cat_Ent.Id);
      Assert
        (Loaded.State = Podmander.Controller.Failed,
         "State should be Failed after failure");
   end Test_Update_On_Failure;

   procedure Test_Update_On_Failure_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Updated : Boolean;
   begin
      Updated := Repo.Update_On_Failure (D, 999);
      Assert
        (not Updated, "Update_On_Failure should return False for unknown id");
   end Test_Update_On_Failure_Not_Found;

   --------------------
   -- Test_Assign_Node
   --------------------

   procedure Test_Assign_Node (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 1);
      Node    : constant Node_Id_Type := Seed_Node (D, "node-1");
      Cat_Ent : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry (D, Service_Id => Svc, Target_Version => 1);
      Updated : Boolean;
      Loaded  : Podmander.Controller.Service_Catalog_Entry;
   begin
      Updated := Repo.Assign_Node (D, Cat_Ent.Id, Node);
      Assert (Updated, "Assign_Node should return True");

      Loaded := Repo.Get_By_Id (D, Cat_Ent.Id);
      Assert
        (Loaded.Assigned_Node.Present
         and then Loaded.Assigned_Node.Node_Id = Node,
         "Node_Id should match after assign");
   end Test_Assign_Node;

   procedure Test_Assign_Node_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Updated : Boolean;
   begin
      Updated := Repo.Assign_Node (D, 999, Node_Id => 1);
      Assert (not Updated, "Assign_Node should return False for unknown id");
   end Test_Assign_Node_Not_Found;

   -------------------
   -- Test_Set_Target
   -------------------

   procedure Test_Set_Target (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Svc     : constant Podmander.Controller.Service_Id_Type :=
        Seed_Service (D, "web", 3);
      Node    : constant Node_Id_Type := Seed_Node (D, "node-1");
      Cat_Ent : constant Podmander.Controller.Service_Catalog_Entry :=
        Repo.Create_Entry
          (D,
           Service_Id     => Svc,
           Node_Id        => (Present => True, Node_Id => Node),
           Target_Version => 2);
      Updated : Boolean;
      Loaded  : Podmander.Controller.Service_Catalog_Entry;
   begin
      -- First mark as failed
      Updated := Repo.Update_On_Failure (D, Cat_Ent.Id);
      Assert (Updated, "Update_On_Failure should return True");

      -- Set new target (should also clear failed)
      Updated := Repo.Set_Target (D, Cat_Ent.Id, Target_Version => 3);
      Assert (Updated, "Set_Target should return True");

      Loaded := Repo.Get_By_Id (D, Cat_Ent.Id);
      Assert
        (Loaded.Target_Version = Podmander.Controller.Service_Version_Type (3),
         "Target_Version should be 3");
      Assert
        (Loaded.State = Podmander.Controller.Pending,
         "State should be Pending after Set_Target");
   end Test_Set_Target;

   procedure Test_Set_Target_Not_Found
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      D       : DB.DB_Handle := DB.Open (":memory:");
      Updated : Boolean;
   begin
      Updated := Repo.Set_Target (D, 999, Target_Version => 1);
      Assert (not Updated, "Set_Target returns False for unknown id");
   end Test_Set_Target_Not_Found;

   overriding
   procedure Register_Tests (T : in out Repository_Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Create_Entry'Access,
         "Create a catalog entry and verify fields");
      Register_Routine
        (T,
         Test_Create_Entry_Unscheduled'Access,
         "Create a catalog entry with no node assigned (unscheduled)");
      Register_Routine (T, Test_Get_By_Id'Access, "Get a catalog entry by id");
      Register_Routine
        (T,
         Test_Get_By_Id_Not_Found'Access,
         "Get by unknown id raises Not_Found");
      Register_Routine
        (T,
         Test_Get_Unscheduled'Access,
         "Get_Unscheduled returns only entries without a node");
      Register_Routine
        (T, Test_Get_Pending'Access, "Get_Pending returns pending entries");
      Register_Routine
        (T,
         Test_Get_Pending_Excludes_Non_Pending'Access,
         "Get_Pending excludes non-Pending entries");
      Register_Routine
        (T,
         Test_Update_On_Success'Access,
         "Update_On_Success sets current_version and state = Deployed");
      Register_Routine
        (T,
         Test_Update_On_Success_Not_Found'Access,
         "Update_On_Success returns False for unknown id");
      Register_Routine
        (T,
         Test_Update_On_Failure'Access,
         "Update_On_Failure sets state = Failed");
      Register_Routine
        (T,
         Test_Update_On_Failure_Not_Found'Access,
         "Update_On_Failure returns False for unknown id");
      Register_Routine
        (T,
         Test_Assign_Node'Access,
         "Assign_Node sets node_id on an unscheduled entry");
      Register_Routine
        (T,
         Test_Assign_Node_Not_Found'Access,
         "Assign_Node returns False for unknown id");
      Register_Routine
        (T,
         Test_Set_Target'Access,
         "Set_Target updates target_version and sets state = Pending");
      Register_Routine
        (T,
         Test_Set_Target_Not_Found'Access,
         "Set_Target returns False for unknown id");
   end Register_Tests;

   Result : aliased AUnit.Test_Suites.Test_Suite;
   TC     : aliased Repository_Test;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      AUnit.Test_Suites.Add_Test (Result'Access, TC'Access);
      return Result'Access;
   end Suite;

end Podmander.Controller.Service_Catalog.Repository_Tests;
