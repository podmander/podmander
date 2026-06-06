---
name: clic-switch-definition
description: CLIC switch definition API - how to define boolean, string, integer, and callback switches
metadata:
  type: reference
---

# CLIC Switch Definition API

From `/tmp/clic/src/clic-subcommand.ads` lines 19-63.

CLIC.Subcommand provides five overloads of `Define_Switch`, all wrapping GNAT.Command_Line.

## Type: Switches_Configuration

```ada
type Switches_Configuration is limited private;
```

A wrapper around GNAT.Command_Line.Command_Line_Configuration. Internally holds:
- `GNAT_Cfg` - the actual GNAT.Command_Line.Command_Line_Configuration
- `Info` - vector of Switch_Info records (for custom usage format, duplicate detection)

## Define_Switch Overloads

All take `Config : in out Switches_Configuration` as the first parameter.

### 1. Untyped Switch (Just a Flag Definition)

```ada
procedure Define_Switch
  (Config      : in out Switches_Configuration;
   Switch      : String := "";
   Long_Switch : String := "";
   Help        : String := "";
   Section     : String := "";
   Argument    : String := "ARG");
```

**Use**: Define a switch without an Output variable. Useful for informational switches or custom handling.

**Example**:
```ada
Define_Switch (Config,
               Switch      => "-v",
               Long_Switch => "--verbose",
               Help        => "Enable verbose output");
```

### 2. Boolean Switch

```ada
procedure Define_Switch
  (Config      : in out Switches_Configuration;
   Output      : access Boolean;
   Switch      : String := "";
   Long_Switch : String := "";
   Help        : String := "";
   Section     : String := "";
   Value       : Boolean := True);
```

**Use**: Define a boolean switch. When the switch is found on the command line, Output.all is set to Value.

**Output initialization**: Output is always initially set to `not Value`, so the variable has a valid value even if the switch isn't used on the command line.

**Example**:
```ada
Help_Switch : aliased Boolean := False;

Define_Switch (Config,
               Help_Switch'Access,
               "-h", "--help",
               "Display help");
-- If user provides -h or --help, Help_Switch becomes True
-- If user doesn't provide it, Help_Switch remains False
```

### 3. Integer Switch

```ada
procedure Define_Switch
  (Config      : in out Switches_Configuration;
   Output      : access Integer;
   Switch      : String := "";
   Long_Switch : String := "";
   Help        : String := "";
   Section     : String := "";
   Initial     : Integer := 0;
   Default     : Integer := 1;
   Argument    : String := "ARG");
```

**Use**: Define a switch that takes an integer parameter.

**Output initialization**: 
- Initialized to `Initial` by default
- If the switch has an optional argument and the user doesn't provide it, Output is set to `Default`

**Example**:
```ada
Verbosity : aliased Integer := 0;

Define_Switch (Config,
               Verbosity'Access,
               "-O:",  -- colon means required argument
               Long_Switch => "--optimization",
               Initial => 0,
               Argument => "LEVEL");
-- User can: -O1, -O 2, --optimization=3, etc.
```

### 4. String Switch

```ada
procedure Define_Switch
  (Config      : in out Switches_Configuration;
   Output      : access GNAT.Strings.String_Access;
   Switch      : String := "";
   Long_Switch : String := "";
   Help        : String := "";
   Section     : String := "";
   Argument    : String := "ARG");
```

**Use**: Define a switch that takes a string parameter. The parsed value is stored in a String_Access.

**Output initialization**: 
- Initialized to empty string if it doesn't already have a value
- Can set a default by pre-initializing the String_Access variable

**Example**:
```ada
Output_File : GNAT.Strings.String_Access;

Define_Switch (Config,
               Output_File'Access,
               "-o",
               Long_Switch => "--output",
               Help        => "Output file name",
               Argument    => "FILE");
-- User can: -o file.txt, --output=file.txt, etc.
-- Result: Output_File points to "file.txt"
```

### 5. Callback Switch

```ada
type Value_Callback is access procedure (Switch, Value : String);

procedure Define_Switch
  (Config      : in out Switches_Configuration;
   Callback    : not null Value_Callback;
   Switch      : String := "";
   Long_Switch : String := "";
   Help        : String := "";
   Section     : String := "";
   Argument    : String := "ARG");
```

**Use**: Define a switch that calls a callback for each instance found.

**Example**:
```ada
procedure Handle_Define (Switch, Value : String) is
begin
  -- Switch = "-D" or "--define"
  -- Value = whatever argument was given
  Put_Line ("Define: " & Value);
end Handle_Define;

Define_Switch (Config,
               Handle_Define'Access,
               "-D",
               Long_Switch => "--define",
               Help        => "Define a symbol",
               Argument    => "SYMBOL");
```

## Switch Format Specifiers (from GNAT.Command_Line)

In the Switch parameter, add one character after the switch name to specify argument handling:

- **`:`** - Required parameter. Space or no space on command line is OK.
  - Example: `-o file` or `-ofile`
  
- **`=`** - Required parameter. Space or `=` on command line OK.
  - Example: `-o file` or `-o=file`
  
- **`!`** - Required parameter. No space (concatenated directly).
  - Example: `-ofile` (not `-o file`)
  
- **`?`** - Optional parameter. No space between switch and parameter.
  - Example: `-ofoo` (with parameter) or `-o foo` (parameter as separate arg)

- **(none)** - No parameter. Switch is a flag.
  - Example: `-v`

**Default for Argument overloads**: Treated as requiring an argument with format `:`

## Example Command with Multiple Switch Types

```ada
procedure Setup_Switches
  (Cmd    : in out My_Command;
   Config : in out CLIC.Subcommand.Switches_Configuration)
is
  use CLIC.Subcommand;
begin
  Define_Switch (Config,
                 Output      => Verbose'Access,
                 Switch      => "-v",
                 Long_Switch => "--verbose",
                 Help        => "Verbose output",
                 Value       => True);

  Define_Switch (Config,
                 Output      => Output_File'Access,
                 Switch      => "-o",
                 Long_Switch => "--output",
                 Help        => "Output file",
                 Argument    => "FILE");

  Define_Switch (Config,
                 Output      => Count'Access,
                 Switch      => "-n",
                 Long_Switch => "--count",
                 Help        => "Item count",
                 Initial     => 1,
                 Argument    => "NUM");
end Setup_Switches;
```

## Notes on GNAT.Command_Line Wrapper

CLIC.Subcommand.Switches_Configuration wraps the lower-level GNAT.Command_Line.Command_Line_Configuration and provides:
- Duplicate switch detection
- Custom usage format support
- Consistent API across all switch types
- The Define_Switch procedures work exactly like GNAT.Command_Line ones

Parsing happens via CLIC.Command_Line (imported from GNAT FSF 11.2).
