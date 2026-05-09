--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Containers.Vectors;
with Ada.Finalization;
with Ada.Unchecked_Deallocation;
with Podmander.Logging;
with Spoon;
with Spoon.Output;

package body Podmander.Agent.Host_Command is

   use type Spoon.Exit_Status;

   package Argument_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Spoon.Argument_Access,
      "="          => Spoon."=");

   --  Owns the heap-allocated Spoon.Argument values for a single Run_Command
   --  invocation. Finalize releases them, so allocations are reclaimed even
   --  when an exception unwinds the call. The type lives in a nested package
   --  spec so its Finalize override is a dispatching primitive.
   package Internals is

      type Argument_Owner is new Ada.Finalization.Limited_Controlled
        with private;

      procedure Add_Argument
        (Owner : in out Argument_Owner;
         Value : String);

      function Build_Spoon_Args
        (Owner : Argument_Owner) return Spoon.Argument_Array;

   private

      type Argument_Owner is new Ada.Finalization.Limited_Controlled
      with record
         Items : Argument_Vectors.Vector;
      end record;

      overriding procedure Finalize (Self : in out Argument_Owner);

   end Internals;

   package body Internals is

      overriding procedure Finalize (Self : in out Argument_Owner) is
         procedure Free_Arg is new Ada.Unchecked_Deallocation
           (Spoon.Argument, Spoon.Argument_Access);
      begin
         for I in Self.Items.First_Index .. Self.Items.Last_Index loop
            declare
               Ptr : Spoon.Argument_Access := Self.Items.Element (I);
            begin
               Free_Arg (Ptr);
            end;
         end loop;
         Self.Items.Clear;
      end Finalize;

      procedure Add_Argument
        (Owner : in out Argument_Owner;
         Value : String) is
      begin
         Owner.Items.Append
           (new Spoon.Argument'(Spoon.To_Argument (Value)));
      end Add_Argument;

      function Build_Spoon_Args
        (Owner : Argument_Owner) return Spoon.Argument_Array
      is
         Length : constant Natural := Natural (Owner.Items.Length);
      begin
         if Length = 0 then
            return [1 .. 0 => null];
         end if;
         return [for I in 1 .. Length =>
                    Owner.Items.Element (I)];
      end Build_Spoon_Args;

   end Internals;

   function Map_Result
     (Raw        : Spoon.Result;
      Program    : String;
      Text       : Spoon.Output.Text_Capturer;
      Err_To_Out : Boolean) return Command_Result
   is
      Stdout : constant SU.Unbounded_String :=
        Spoon.Output.Text_Capturer (Text).Get
          (Spoon.Standard_Output);
      Stderr : constant SU.Unbounded_String :=
        Spoon.Output.Text_Capturer (Text).Get
          (Spoon.Standard_Error);
   begin
      case Raw.State is
         when Spoon.Exited =>
            if Raw.Exit_Status = Spoon.Success then
               Podmander.Logging.Info
                 ("host-command",
                  "Ran " & Program
                  & " -> exit" & Spoon.Exit_Status'Image (Raw.Exit_Status));
            else
               Podmander.Logging.Warning
                 ("host-command",
                  "Ran " & Program
                  & " -> exit" & Spoon.Exit_Status'Image (Raw.Exit_Status));
            end if;
            return
              (State        => Exited,
               Exit_Status  => Exit_Status (Raw.Exit_Status),
               Output       =>
                 (if Err_To_Out
                  then SU.To_Unbounded_String
                         (SU.To_String (Stdout)
                          & SU.To_String (Stderr))
                  else Stdout),
               Error_Output =>
                 (if Err_To_Out
                  then SU.Null_Unbounded_String
                  else Stderr));
         when Spoon.Error =>
            Podmander.Logging.Error
              ("host-command",
               "Spawn error" & Integer'Image (Raw.Error_Code)
               & " for " & Program);
            return
              (State        => Error,
               Error_Code   => Raw.Error_Code,
               Output       => Stdout,
               Error_Output => Stderr);
         when Spoon.Crashed =>
            Podmander.Logging.Error
              ("host-command",
               Program & " crashed with signal"
               & Positive'Image (Raw.Signal));
            return
              (State        => Crashed,
               Signal       => Raw.Signal,
               Output       => Stdout,
               Error_Output => Stderr);
         when Spoon.Terminated =>
            Podmander.Logging.Error
              ("host-command",
               Program & " terminated with signal"
               & Positive'Image (Raw.Signal));
            return
              (State        => Terminated,
               Signal       => Raw.Signal,
               Output       => Stdout,
               Error_Output => Stderr);
      end case;
   end Map_Result;

   function Run_Command
     (Program    : String;
      Args       : Argument_List;
      Err_To_Out : Boolean := False) return Command_Result
   is
      Text  : aliased Spoon.Output.Text_Capturer;
      Owner : Internals.Argument_Owner;
   begin
      Podmander.Logging.Debug
        ("host-command",
         "Spawning " & Program & " with"
         & Natural'Image (Args'Length) & " args");

      for I in Args'Range loop
         Internals.Add_Argument (Owner, SU.To_String (Args (I)));
      end loop;

      declare
         Spoon_Args : constant Spoon.Argument_Array :=
           Internals.Build_Spoon_Args (Owner);
         Raw : constant Spoon.Result :=
           Spoon.Spawn
             (Executable => Program,
              Arguments  => Spoon_Args,
              Kind       => Spoon.File_Path,
              Output     => Text'Access);
      begin
         return Map_Result (Raw, Program, Text, Err_To_Out);
      end;
   end Run_Command;

   function Run_Command_Shell
     (Command    : String;
      Err_To_Out : Boolean := False) return Command_Result
   is
      Args : constant Argument_List := [+"-c", +Command];
   begin
      return Run_Command ("/bin/sh", Args, Err_To_Out => Err_To_Out);
   end Run_Command_Shell;

end Podmander.Agent.Host_Command;
