# Logging Facility Implementation Plan

**Requirements:** [logging-requirements.md](logging-requirements.md)
**Date:** 2026-04-16

## Implementation Units

### Unit 1: Logging Package

**Goal:** Create `Podmander.Logging` with level enum, filtering, and console output formatting.

**Requirements trace:** R1, R2, R3, R5, R8

**Dependencies:** None

**Files:**
- `src/shared/podmander-logging.ads` — level enum, logging procedures, level config
- `src/shared/podmander-logging.adb` — formatting, TTY detection, level filtering
- `tests/podmander-logging_tests.adb` — unit tests
- `tests/podmander-logging_tests.ads` — test package spec
- `tests/test_runner.adb` — add logging suite

**Approach:**

1. Define `Log_Level` enum: `Debug, Info, Warning, Error, Critical` with mapping to syslog priorities (7/6/4/3/2).

2. Global minimum level variable (default Info) with `Set_Level` / `Get_Level` procedures.

3. One procedure per level:
   ```ada
   procedure Debug    (Component : String; Message : String);
   procedure Info     (Component : String; Message : String);
   procedure Warning  (Component : String; Message : String);
   procedure Error    (Component : String; Message : String);
   procedure Critical (Component : String; Message : String);
   ```

4. Each procedure checks current level, skips if below minimum.

5. Output format depends on TTY detection (`Ada.Command_Line` or `isatty()`):
   - **Under systemd/journald**: `<N>message` (syslog priority prefix)
   - **In terminal**: `[LEVEL] [component] message`

6. TTY detection: check if stdout is a TTY using `GNAT.OS_Lib.Is_Tty` or equivalent. If unavailable, default to TTY format (safe for development; systemd captures it fine anyway because journald also parses non-prefixed output).

**Patterns:** Follow existing `Podmander.CLI` package patterns for shared utility code.

**Test scenarios:**
- [ ] Debug message suppressed when level is Info
- [ ] Info message emitted when level is Info
- [ ] Warning message emitted regardless of level being Info
- [ ] All 5 levels emitted when level is Debug
- [ ] Component name appears in formatted output
- [ ] Level string appears in formatted output

**Verification:** Unit tests pass, package compiles and links into existing test suite.

**Planning-time unknowns:**
- Availability of TTY detection in GNAT runtime — Deferred to Implementation

---

### Unit 2: Replace Controller Call Sites

**Goal:** Replace all `Ada.Text_IO.Put_Line` calls in controller code with `Podmander.Logging` calls.

**Requirements trace:** R4, R6, R7, R8

**Dependencies:** Unit 1

**Files:**
- `src/controller/podmander-controller.adb` — replace 4 call sites
- `src/controller/podmander-controller-message_handlers.adb` — replace 5 call sites
- `src/bin/pod_controller.adb` — add `--log-level` CLI flag, set level on startup

**Approach:**

Map existing call sites to logging calls:

| Current message | Level | Component |
|----------------|-------|-----------|
| `"Controller listening on ..."` | Info | controller |
| `"WARNING: Malformed message from ..."` | Warning | controller |
| `"Agent ... DISCONNECTED"` | Warning | controller |
| `"Agent ... UNRESPONSIVE"` | Warning | controller |
| `"WARNING: Invalid enrollment secret from ..."` | Warning | controller |
| `"Registered agent ... as ..."` | Info | controller |
| `"Agent ... reconnected"` | Info | controller |
| `"Heartbeat from ..."` | Debug | controller |
| `"WARNING: Heartbeat from unregistered agent ..."` | Warning | controller |

**Patterns:** Existing message text preserved, `WARNING:` prefix removed (level conveys it).

**Test scenarios:**
- [ ] Controller startup shows Info-level bind address
- [ ] Heartbeat messages suppressed at default Info level
- [ ] Heartbeat messages visible at Debug level
- [ ] Warning messages show without `WARNING:` prefix

**Verification:** Controller runs, output uses new logging format, no `Ada.Text_IO` imports remain in controller package body.

**Planning-time unknowns:** None

---

### Unit 3: Replace Agent Call Sites

**Goal:** Replace all `Ada.Text_IO.Put_Line` calls in agent code with `Podmander.Logging` calls.

**Requirements trace:** R4, R6, R7, R8

**Dependencies:** Unit 1

**Files:**
- `src/agent/podmander-agent.adb` — replace 8 call sites
- `src/bin/pod_agent.adb` — add `--log-level` CLI flag, set level on startup

**Approach:**

Map existing call sites:

| Current message | Level | Component |
|----------------|-------|-----------|
| `"Agent ... starting, controller at ..."` | Info | agent |
| `"Connecting to controller..."` | Info | agent |
| `"Sent registration request"` | Debug | agent |
| `"Registration timeout, retrying in..."` | Warning | agent |
| `"Registered as ..."` | Info | agent |
| `"WARNING: Unexpected response during enrollment"` | Warning | agent |
| `"WARNING: Malformed response during enrollment"` | Warning | agent |
| `"Sent heartbeat"` | Debug | agent |
| `"Connection lost, reconnecting..."` | Warning | agent |

**Patterns:** Same as controller — preserve message text, remove `WARNING:` prefix.

**Test scenarios:**
- [ ] Agent startup shows Info-level identity message
- [ ] Heartbeat send messages suppressed at Info level
- [ ] Heartbeat send messages visible at Debug level
- [ ] Registration timeout shows as Warning

**Verification:** Agent runs, output uses new logging format, no `Ada.Text_IO` imports remain in agent package body.

**Planning-time unknowns:** None

---

### Unit 4: Replace CLI Call Site

**Goal:** Replace the one `Ada.Text_IO.Put_Line` call in CLI package.

**Requirements trace:** R4

**Dependencies:** Unit 1

**Files:**
- `src/shared/podmander-cli.adb` — replace 1 call site (invalid duration warning)

**Approach:** Map `"WARNING: Invalid value for --..."` to `Podmander.Logging.Warning ("cli", ...)`.

**Test scenarios:**
- [ ] Invalid duration flag produces Warning-level log

**Verification:** CLI warning uses logging package.

**Planning-time unknowns:** None

---

## Quality Bar Checklist

- [ ] Every unit has a requirements trace
- [ ] Dependencies form a DAG (no cycles)
- [ ] Every unit has at least 3 test scenarios
- [ ] No unit touches >8 files (max is Unit 1 with 5 files)
- [ ] No more than 2 new abstractions introduced per unit (Unit 1: 1 new package)
- [ ] Every planning-time unknown is classified as blocker or deferred
- [ ] Handoff completeness test: engineer can implement without inventing behavior