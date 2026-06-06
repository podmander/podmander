---
name: clic-instance-generic
description: CLIC.Subcommand.Instance generic instantiation - parameters, registration, execution
metadata:
  type: reference
---

# CLIC.Subcommand.Instance Generic

From `/tmp/clic/src/clic-subcommand-instance.ads` lines 5-142.

## Formal Generic Parameters

```ada
package CLIC.Subcommand.Instance is

   Main_Command_Name : String;
   -- Name of the main command or program

   Version : String;
   -- Version of the program

   with procedure Set_Global_Switches
     (Config : in out CLIC.Subcommand.Switches_Configuration);
   -- Define global switches using CLIC.Subcommand.Define_Switch

   with procedure Put (Str : String);
   -- Used to print help and usage

   with procedure Put_Line (Str : String);
   -- Used to print help and usage

   with procedure Put_Error (Str : String);
   -- Used to print errors

   with procedure Error_Exit (Code : Integer);
   -- Signal program should terminate (typically GNAT.OS_Lib.OS_Exit)

   with function TTY_Chapter (Str : String) return String;
   with function TTY_Description (Str : String) return String;
   with function TTY_Version (Str : String) return String;
   with function TTY_Underline (Str : String) return String;
   with function TTY_Emph (Str : String) return String;
   -- Formatting functions for output (use CLIC.Subcommand.No_TTY for no formatting)

   Global_Options_In_subcommand_help : Boolean := True;
   -- When listing help for a subcommand, also include a section on global options
```

## Procedures Provided by Instance

### Registration

```ada
procedure Register (Cmd : not null Command_Access);
-- Register a sub-command

procedure Register (Group : String; Cmd : not null Command_Access);
-- Register a sub-command in a group

procedure Register (Topic : not null Help_Topic_Access);
-- Register a help topic

procedure Set_Alias (Alias : Identifier; Replacement : AAA.Strings.Vector);
-- Define Alias such that "<Main_Command_Name> <Alias> <Extra_Args>" 
-- will be replaced by "<Main_Command_Name> <Replacement> <Extra_Args>"

procedure Load_Aliases (Conf : CLIC.Config.Instance; Root_Key : String := "alias");
-- Load aliases from configuration (keys like "alias.test1" = "cmd arg1 arg2")
```

### Execution/Parsing

```ada
procedure Execute
  (Command_Line : AAA.Strings.Vector := AAA.Strings.Empty_Vector);
-- Parse the command line and execute a sub-command or display help/usage
-- If Command_Line is not empty, it will be used instead of Ada.Command_Line

procedure Parse_Global_Switches
  (Command_Line : AAA.Strings.Vector := AAA.Strings.Empty_Vector);
-- Optional. Parse only global switches (before the subcommand).
-- Useful to check global switch values before running a subcommand.
```

### Introspection/Display

```ada
function What_Command return String;
-- Return the name of the command that was parsed

procedure Display_Usage (Displayed_Error : Boolean := False);
-- Display usage information

procedure Display_Help (Keyword : String);
-- Display help for a specific command or topic

function Is_Global_Switch (Switch : String) return Boolean;
-- Say if the switch has been defined as global
```

### Exceptions

```ada
Error_No_Command : exception;
-- Raised when no command is found

Command_Already_Defined : exception;
-- Raised when registering a command that already exists
```

### Built-in Help Command

```ada
type Builtin_Help is new Command with private;
-- Use Register (new Builtin_Help); to provide a built-in help command
```

## Example Instantiation (from example code)

From `/tmp/clic/example/src/clic_ex-commands.ads` lines 19-31:

```ada
package Sub_Cmd is new CLIC.Subcommand.Instance
  (Main_Command_Name   => "clic_example",
   Version             => "0.0.0",
   Set_Global_Switches => Set_Global_Switches,
   Put                 => Ada.Text_IO.Put,
   Put_Line            => Ada.Text_IO.Put_Line,
   Put_Error           => Ada.Text_IO.Put_Line,
   Error_Exit          => GNAT.OS_Lib.OS_Exit,
   TTY_Chapter         => CLIC.TTY.Info,
   TTY_Description     => CLIC.TTY.Description,
   TTY_Version         => CLIC.TTY.Version,
   TTY_Underline       => CLIC.TTY.Underline,
   TTY_Emph            => CLIC.TTY.Emph);
```

## Typical Execution Pattern

From example body:

1. `Sub_Cmd.Parse_Global_Switches;` - parse and check global switches
2. Configure TTY/color based on global switches
3. Load configuration from TOML
4. `Sub_Cmd.Load_Aliases(Config_DB);` - register aliases
5. `Sub_Cmd.Register(...)` - register commands during elaboration or early in Execute
6. `Sub_Cmd.Execute;` - parse command line and dispatch
