--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Text_IO;
with Interfaces.C;

package body Podmander.Logging is

   Minimum_Level : Log_Level := Info;

   Syslog_Priorities : constant array (Log_Level) of Natural :=
     [Debug    => 7,
      Info     => 6,
      Warning  => 4,
      Error    => 3,
      Critical => 2];

   Level_Labels : constant array (Log_Level) of String (1 .. 8) :=
     [Debug    => "DEBUG   ",
      Info     => "INFO    ",
      Warning  => "WARNING ",
      Error    => "ERROR   ",
      Critical => "CRITICAL"];

   Is_Terminal : Boolean := False;
   TTY_Checked : Boolean := False;

   function C_Isatty (Fd : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Isatty, "isatty");

   function Running_In_Terminal return Boolean is
      use type Interfaces.C.int;
   begin
      if not TTY_Checked then
         Is_Terminal := C_Isatty (1) /= 0;
         TTY_Checked := True;
      end if;
      return Is_Terminal;
   end Running_In_Terminal;

   procedure Set_Level (Level : Log_Level) is
   begin
      Minimum_Level := Level;
   end Set_Level;

   function Get_Level return Log_Level is
   begin
      return Minimum_Level;
   end Get_Level;

   procedure Emit
     (Level     : Log_Level;
      Component : String;
      Message   : String) is
      Pri_Str : constant String :=
        Syslog_Priorities (Level)'Image;
      Pri_Tr  : constant String :=
        Pri_Str (Pri_Str'First + 1 .. Pri_Str'Last);
   begin
      if Level < Minimum_Level then
         return;
      end if;

      if Running_In_Terminal then
         Ada.Text_IO.Put_Line
           ("[" & Level_Labels (Level) & "] "
            & "[" & Component & "] " & Message);
      else
         Ada.Text_IO.Put_Line
           ("<" & Pri_Tr & ">" & Message);
      end if;
   end Emit;

   procedure Debug (Component : String; Message : String) is
   begin
      Emit (Debug, Component, Message);
   end Debug;

   procedure Info (Component : String; Message : String) is
   begin
      Emit (Info, Component, Message);
   end Info;

   procedure Warning (Component : String; Message : String) is
   begin
      Emit (Warning, Component, Message);
   end Warning;

   procedure Error (Component : String; Message : String) is
   begin
      Emit (Error, Component, Message);
   end Error;

   procedure Critical (Component : String; Message : String) is
   begin
      Emit (Critical, Component, Message);
   end Critical;

end Podmander.Logging;