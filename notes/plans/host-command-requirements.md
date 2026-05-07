# Host_Command Requirements

**Version:** 1.2
**Status:** Draft
**Date:** 2026-05-07
**Issue:** podmander/podmander#16

## Problem Frame

The agent's host-system interactions use two inconsistent patterns:
`GNAT.OS_Lib.Spawn` with manual argument-list allocation (Deployer) and
`/bin/sh -c` with a hardcoded temp file for output capture (Status_Collector).
The temp-file approach has a race condition under concurrent queries, and
neither pattern captures stderr or reports meaningful error detail. As more
host interactions are added, each would reinvent its own spawn pattern.

Alongside the spawn-pattern problem, response messages (`Deploy_Result`,
`Status_Response`) lack a uniform error model: the controller cannot
distinguish transient failures from permanent ones, so retry semantics are
not expressible on the wire. R7 below addresses that gap as part of the
same change set.

## Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R1 | Spawn a command given a program path and argument list, capturing stdout and stderr into strings | Must Have | Replaces both current patterns |
| R2 | Return a discriminated result type: Exited (exit code + output), Crashed (signal + output), Terminated (signal + output), Error (spawn failure reason) | Must Have | Mirrors Spoon's result model; matches Ada safety idiom from AGENTS.md |
| R3 | Merge stderr into stdout on demand (Err_To_Out flag) | Must Have | Replaces `2>/dev/null` and `2>&1` shell hacks |
| R4 | Log command invocations and results via Podmander.Logging | Must Have | Debug-level for invocation, Info on success, Warning on non-zero exit, Error on Crashed/Terminated/spawn-Error |
| R5 | Support shell-string invocations only through explicit opt-in (Run_Command_Shell) | Should Have | Prevents shell injection by default; needed for podman format strings |
| R7 | Deploy_Result and Status_Response carry a Result_Code field (Ok, Failed, Unavailable, Invalid_Argument, Internal) so the controller can distinguish success from transient vs permanent failure | Must Have | Inspired by gRPC status codes; enables retry semantics and operator visibility |

R6 (thread-safety via protected type) was considered and dropped: the agent
is single-tasked today and the abstraction exposes plain functions. Re-add
when a second concurrent caller actually appears.

## Success Criteria

- Status_Collector no longer uses temp files or `/bin/sh -c`
- Deployer no longer manually allocates/frees `GNAT.OS_Lib.Argument_List`
- Both packages call Host_Command for all process spawning
- A test suite covers happy path, command-not-found, non-zero exit, stderr capture (separate and merged), shell-string invocation, and many-argument calls
- No new GNAT.OS_Lib or GNAT.Expect imports in consumer packages
- Deploy_Result and Status_Response carry Result_Code on the wire
- Controller can distinguish transient failures (Unavailable) from permanent ones (Failed)
- Status_Response carries Containers and Error_Message as separate fields,
  not an overloaded single string

## Scope Boundaries

**In scope:**
- `Podmander.Agent.Host_Command` package (spec + body)
- `Podmander.Agent.Host_Command.Result_Mapping` child package (Command_Result → Result_Code)
- `Podmander.Messages.Result_Codes` package (Result_Code enum + wire encoding)
- Refactoring Deployer to consume Host_Command
- Refactoring Status_Collector to consume Host_Command
- Adding Result_Code to Deploy_Result and Status_Response wire formats
- Splitting Status_Response into Containers + Error_Message fields
- Unit tests for Host_Command and Result_Mapping
- Adding `spoon` as an Alire dependency

**Out of scope:**
- File I/O abstraction (quadlet writing, config reading)
- Generator packages (systemd, Caddy, Restic generators)
- Controller-side host interactions (none exist)
- Integration tests (gated behind flag per AGENTS.md)
- Timeouts and bounded output capture (deferred — see Q2)
- Errno/signal-aware Result_Code refinement (see Result_Mapping comment)

## Key Decisions

| Decision | Chosen | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Process library | Spoon (Alire crate) | Apache-2.0; built-in output capture via protected type; `posix_spawn`; small codebase; Jochen accepts fork risk | GNAT.Expect (not task-safe), gnatcoll (heavy, license), utilada (overkill), raw GNAT.OS_Lib (no output capture) |
| Result type | Discriminated record mirroring Spoon | Exited/Crashed/Terminated/Error variants give consumers precise failure info | Boolean + error string (loses signal vs exit-code distinction) |
| Scope | Process spawning only | File I/O is a separate concern; YAGNI | Combined host-operations package (wider scope, unclear benefit) |
| Shell invocations | Opt-in via separate subprogram | Default-safe; shell injection requires explicit choice | Always-via-shell (convenient but dangerous), never-shell (can't handle podman format strings) |
| Protocol error model | Result_Code enum (Ok/Failed/Unavailable/Invalid_Argument/Internal) on Deploy_Result and Status_Response | Inspired by gRPC status codes: encodes retry semantics and responsibility; uniform across both response types; extensible | Per-message Success/Failed booleans (inconsistent), HTTP-style numeric codes (overloaded), full gRPC 17 codes (YAGNI) |
| Protocol record shape | Flat records with `Code : Result_Code` field | Variants would carry the same fields across all cases — discrimination buys no structural benefit | Discriminated records (rejected after early planning showed redundant fields) |
| Status_Response payload | Two named fields (Containers, Error_Message) | Symmetric with Deploy_Result; controller does not have to branch on Code to interpret a single string | Single overloaded Payload string (rejected — implicit contract) |
| Argument storage | `Ada.Containers.Vectors` of `Spoon.Argument_Access` owned by a `Limited_Controlled` wrapper | No silent ceiling; deallocation runs even on exception unwind; AGENTS.md prefers controlled types over raw Unchecked_Deallocation | Fixed-size array (silent truncation), raw pointer cleanup (leak risk on exception) |
| Mapping location | Child package `Host_Command.Result_Mapping` | Keeps Host_Command core free of protocol dependencies; one place for all consumers | In Host_Command (couples to protocol), per-consumer (duplicates code) |

## Outstanding Questions

| # | Question | Impact if Wrong | Owner | Status |
|---|----------|-----------------|-------|--------|
| Q1 | Does Spoon compile and link cleanly with the current GNAT/Alire toolchain in the `ada_dev` distrobox? | Blocks all implementation | Jochen + Agent | Resolved 2026-05-07 |
| Q2 | Does Spoon handle commands that produce large output (e.g., `podman logs`) without blocking or buffering issues? | May need output truncation, streaming, or timeout | Agent | Deferred — tracked as podmander/podmander#19. Run_Command currently blocks with no output bound; consumers must avoid commands that may run indefinitely. |
