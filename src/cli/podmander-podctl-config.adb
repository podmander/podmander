--  Copyright (C) 2026 Jochen Lillich
--  SPDX-License-Identifier: Apache-2.0

with Ada.Environment_Variables;
with TOML;
with TOML.File_IO;

package body Podmander.Podctl.Config is

   Default_Config_Suffix : constant String := "/.config/podmander/podctl.toml";

   function Resolve_Path (Config_File : String) return String is
   begin
      if Config_File /= "" then
         return Config_File;
      end if;
      return
        Ada.Environment_Variables.Value ("HOME", "") & Default_Config_Suffix;
   end Resolve_Path;

   function Load
     (Config_File         : String := "";
      Controller_Override : String := "";
      Token_Override      : String := "") return Load_Result
   is
      Path       : constant String := Resolve_Path (Config_File);
      Controller : Unbounded_String :=
        To_Unbounded_String (Default_Controller);
      Token      : Unbounded_String := Null_Unbounded_String;
   begin
      --  Load from file; a missing or unparseable file is silently skipped.
      if Path /= "" then
         declare
            File_Result : constant TOML.Read_Result :=
              TOML.File_IO.Load_File (Path);
         begin
            if File_Result.Success then
               if File_Result.Value.Has ("controller") then
                  Controller :=
                    To_Unbounded_String
                      (File_Result.Value.Get ("controller").As_String);
               end if;
               if File_Result.Value.Has ("token") then
                  Token :=
                    To_Unbounded_String
                      (File_Result.Value.Get ("token").As_String);
               end if;
            end if;
         end;
      end if;

      --  Command-line flags override file values.
      if Controller_Override /= "" then
         Controller := To_Unbounded_String (Controller_Override);
      end if;
      if Token_Override /= "" then
         Token := To_Unbounded_String (Token_Override);
      end if;

      if Token = Null_Unbounded_String then
         return
           (Success => False,
            Message => To_Unbounded_String ("token is required"));
      end if;

      return
        (Success => True, Value => (Controller => Controller, Token => Token));
   end Load;

end Podmander.Podctl.Config;
