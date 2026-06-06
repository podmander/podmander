--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Strings.Unbounded;
with Podmander.Database;

package Podmander.Controller.Stack_Submission is

   use Ada.Strings.Unbounded;
   use Podmander.Database;

   type Submission_Error is
     (None, Parse_Failed, Registration_Failed, Schedule_Failed);

   type Submission_Result is record
      Ok      : Boolean := False;
      Error   : Submission_Error := None;
      Message : Unbounded_String;
   end record;

   function Submit
     (DB : in out DB_Handle; TOML_Content : String) return Submission_Result;
   --  Submit a stack for deployment:
   --  1. Parse the TOML content into a Service_Definition
   --  2. Register the service and create a version
   --  3. Schedule the service for deployment
   --  Returns a Submission_Result indicating success or which stage failed.

end Podmander.Controller.Stack_Submission;
