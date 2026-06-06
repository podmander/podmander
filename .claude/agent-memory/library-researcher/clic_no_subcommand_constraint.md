---
name: clic-no-subcommand-constraint
description: CRITICAL - CLIC requires subcommand; no native single-command mode
metadata:
  type: reference
---

# CLIC Structural Requirement: Subcommands Are Mandatory

**CRITICAL FINDING**: CLIC structurally requires at least one subcommand. There is no native "single-command" or "no-subcommand" mode.

## Evidence

### 1. Execute Procedure Logic (Instance.adb lines 645-774)

```ada
procedure Execute
  (Command_Line : AAA.Strings.Vector := AAA.Strings.Empty_Vector)
is
begin
  Parse_Global_Switches (Command_Line);

  if Global_Arguments.Is_Empty then
     --  We should at least have the sub-command name in the arguments
     Display_Usage;
     Error_Exit (1);
  elsif Help_Requested then
     Display_Help (Global_Arguments.First_Element);
     Error_Exit (0);
  end if;
  
  -- ... (lines 665-666)
  declare
    Cmd : constant not null Command_Access := What_Command;
    --  Might raise if invalid, if so we are done
```

**Key points**:
- Line 655-658: If `Global_Arguments` is empty (no command name found), displays usage and exits with code 1
- Line 671: Calls `What_Command` which searches Registered_Commands for a match
- If no command is found, raises `Error_No_Command` exception (line 269)

### 2. What_Command Function (Instance.adb lines 277-287)

```ada
function What_Command return String is
begin
  if Global_Arguments.Is_Empty
    or else
      AAA.Strings.Has_Prefix (Global_Arguments.First_Element, "-")
  then
     raise Error_No_Command;
  else
     return Global_Arguments.First_Element;
  end if;
end What_Command;
```

**Key point**: If the first global argument is empty OR starts with "-" (a switch, not a command), raises `Error_No_Command`.

### 3. Global_Arguments Vector Behavior

- `Global_Arguments` is populated by `Parse_Global_Switches` and contains everything after global switches
- It **must** start with a command name
- Switches (starting with "-") are explicitly rejected as command names (line 281)

## Workaround: Use a Default "Main" Command

If you need a single-command tool with CLIC, the idiomatic pattern is:

1. Create a single Command implementation (e.g., `Main_Command`)
2. Register it with a simple name like `"main"` or your tool name
3. Instruct users to invoke: `mytool main --flag=x --other=y`
4. Or use a wrapper script that automatically inserts the command name

**Example**:
```ada
-- Register a single command
Sub_Cmd.Register (new Main_Command'(null record));

-- Users would invoke: mytool main --flag=x
```

Alternatively, a shell wrapper:
```bash
#!/bin/bash
exec mytool main "$@"
```

## Why CLIC Requires Subcommands

The library is explicitly designed as "git-like subcommand handling" (per alire.toml). The core dispatch mechanism assumes:
1. Parse global switches
2. Extract first non-switch argument as the command name
3. Look up command in registry
4. Dispatch to Execute

This architecture doesn't have a fallback for "no command specified" → execute a default. The help system and built-in commands (Builtin_Help, potentially version) all expect a command dispatch model.

## Build-in Help Command

CLIC provides `Builtin_Help` which can be registered:
```ada
Sub_Cmd.Register (new Sub_Cmd.Builtin_Help);
```

This creates a `help` command that can be invoked as `mytool help <command>` or `mytool help <topic>`, but it does not eliminate the requirement for a command verb.

## Verdict

**CLIC is fundamentally incompatible with single-verb, switch-only tools.** It must always dispatch through a registered Command. If a tool must support switch-only usage, CLIC is not the right choice.
