---
name: clic-command-interface
description: CLIC Command interface - abstract type and primitive operations required
metadata:
  type: reference
---

# CLIC.Subcommand.Command Interface

From `/tmp/clic/src/clic-subcommand.ads` lines 73-135.

## Abstract Type

```ada
type Command is limited interface;
type Command_Access is access all Command'Class;
```

## Primitive Operations (All Abstract, Must Override)

1. **Name** - required
   ```ada
   function Name (Cmd : Command) return Identifier is abstract;
   ```
   - Returns the subcommand name (used in usage/command line)
   - Example: `"my_app <name>"` where `<name>` is the Name
   - Identifier type: String with predicate allowing a-z, A-Z, 0-9, -, ., _

2. **Switch_Parsing** - required
   ```ada
   function Switch_Parsing (Cmd : Command) return Switch_Parsing_Kind is abstract;
   ```
   - Returns one of: `Parse_All`, `Before_Double_Dash`, `All_As_Args`
   - Controls how the command's command-line arguments are parsed for switches

3. **Execute** - required
   ```ada
   procedure Execute (Cmd  : in out Command;
                      Args :        AAA.Strings.Vector) is abstract;
   ```
   - Implements the command functionality
   - Args: vector of non-switch arguments (after parsing)

4. **Long_Description** - required
   ```ada
   function Long_Description (Cmd : Command) return AAA.Strings.Vector is abstract;
   ```
   - Returns detailed description as vector of paragraphs (each reformatted to appropriate line length)

5. **Short_Description** - required
   ```ada
   function Short_Description (Cmd : Command) return String is abstract;
   ```
   - One-liner shown in command list and as SUMMARY in command help

6. **Usage_Custom_Parameters** - required
   ```ada
   function Usage_Custom_Parameters (Cmd : Command) return String is abstract;
   ```
   - The part after `"<main> [global options] command [command options] "` in USAGE output
   - Non-switch-managed parameters specific to this command

7. **Setup_Switches** - optional (default is null/no-op)
   ```ada
   procedure Setup_Switches
     (Cmd    : in out Command;
      Config : in out Switches_Configuration)
   is null;
   ```
   - Called once the command has been identified, before Execute
   - Config must be set up with the switches used by the command

## Helper Type

```ada
type Switch_Parsing_Kind is
  (Parse_All,           -- All args parsed for switches
   Before_Double_Dash,  -- Only before "--", rest passed to Execute
   All_As_Args          -- Skip all switch parsing, everything to Execute
  );
```
