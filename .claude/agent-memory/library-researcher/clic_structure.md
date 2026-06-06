---
name: clic-package-structure
description: CLIC (crate name 'clic') package structure, versioning, and core modules
metadata:
  type: reference
---

# CLIC Library Overview

**Current Version**: 0.3.0 (from alire.toml)

**Repository**: https://github.com/alire-project/clic

**License**: MIT AND GPL-3.0-or-later WITH GCC-exception-3.1

## Main Packages

- **CLIC** - root package (Preelaborate), utility functions for UTF-8 encoding/decoding
- **CLIC.Subcommand** - core interface types: `Command`, `Help_Topic`, `Switches_Configuration`
- **CLIC.Subcommand.Instance** - generic package that instantiates parser/executor for a specific app
- **CLIC.TTY** - terminal color/formatting with AnsiAda, TTY detection
- **CLIC.User_Input** - interactive prompts, yes/no/multi-choice queries with non-interactive fallback
- **CLIC.Config** - TOML-based configuration system with key/value storage
- **CLIC.Command_Line** - imported from GNAT FSF 11.2, low-level command-line parsing

## Dependencies (from alire.toml)

- aaa ~0.2.4 (AAA.Strings, AAA.Table_IO, AAA.Text_IO)
- simple_logging ^1.2.0
- ansiada ^1.0
- ada_toml ~0.2|~0.3
