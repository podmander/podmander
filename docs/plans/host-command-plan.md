# Host_Command Implementation Plan

## Architecture

`Podmander.Agent.Host_Command` is a thin wrapper over Spoon's `Spawn` API.
It translates Spoon's result type into a Podmander-domain result type and
adds logging + stderr-merge semantics. Consumers (Deployer, Status_Collector)
never import Spoon directly.

The protocol-level Result_Code mapping lives in a sibling child package,
`Podmander.Agent.Host_Command.Result_Mapping`, so the spawn primitive does
not depend on the message protocol.

`Deploy_Result` and `Status_Response` carry a `Result_Code` field
(defined in `Podmander.Messages.Result_Codes`) so the controller can
distinguish transient from permanent failures and decide whether to retry.

```
Consumer (Deployer / Status_Collector)
  │
  ├─▶ Podmander.Agent.Host_Command            ← spawn primitive (Spoon-backed)
  │     │
  │     ▼
  │   Spoon                                    ← Alire dependency
  │
  └─▶ Podmander.Agent.Host_Command.Result_Mapping
        │
        ▼
      Podmander.Messages.Result_Codes          ← protocol vocabulary
```

Wire format for response messages with a Result_Code:

```
Frame 0: kind string          ← "deploy_ack" / "status_ack"
Frame 1: result_code string   ← "OK" | "FAILED" | "UNAVAILABLE" | "INVALID_ARGUMENT" | "INTERNAL"
Frame 2..N: payload frames    ← per-type payload
  deploy_ack: Frame 2 = service_name, Frame 3 = error_message
  status_ack: Frame 2 = containers,   Frame 3 = error_message
```

---

### Unit 1: Add Spoon dependency

**Goal:** Make Spoon available as an Alire dependency and confirm the project builds.

**Requirements trace:** prerequisite for R1 (does not itself fulfill any requirement)

**Dependencies:** None

**Files:**
- `alire.toml` — add `spoon = "~1.0.1"` to `[[depends-on]]`

**Approach:** Add the dependency, run `alr with --solve && alr build` to verify.

**Patterns:** Follow existing dependency entries in alire.toml.

**Verification:** `alr build` completes without errors.

**Planning-time unknowns:** None — Spoon already verified to compile with current toolchain.

---

### Unit 2: Create Host_Command package (TDD)

**Goal:** Write tests first, then implement `Podmander.Agent.Host_Command` to make them pass.

**Requirements trace:** R1, R2, R3, R4, R5

**Dependencies:** Unit 1

**Files:**
- `tests/podmander-agent-host_command_tests.ads` — new test spec (write first)
- `tests/podmander-agent-host_command_tests.adb` — new test body (write first)
- `tests/test_runner.adb` — register new test package
- `src/agent/podmander-agent-host_command.ads` — new spec with `Command_Result` type and subprogram declarations
- `src/agent/podmander-agent-host_command.adb` — new body implementing `Run_Command` and `Run_Command_Shell` via Spoon

**TDD sequence:**

1. **Red:** Write test spec + body with all test scenarios. Write minimal Host_Command spec (types + subprogram declarations only, no body yet). Tests will fail to link.
2. **Green:** Implement Host_Command body via Spoon. Run tests until all pass.
3. **Clean up:** Refactor if needed.

**Test scenarios (written first):**
- Test_Run_Echo_Success: `echo hello` → Exited, Exit_Status = 0, Output contains "hello"
- Test_Run_False_Nonzero: `false` → Exited, Exit_Status /= 0
- Test_Run_Nonexistent_Error: `/nonexistent_cmd` → Error variant
- Test_Run_Stderr_Separate: `sh -c "echo err >&2"` with Err_To_Out=False → Error_Output contains "err", Output is empty
- Test_Run_Stderr_Merged: `sh -c "echo out && echo err >&2"` with Err_To_Out=True → Output contains both "out" and "err"
- Test_Run_Shell_Echo: `Run_Command_Shell("echo hello")` → Exited, Output contains "hello"
- Test_Run_Shell_Pipeline: `Run_Command_Shell("echo hello | tr h H")` → Exited, Output contains "Hello"
- Test_Run_Many_Args: 12-argument echo → all args present in output (proves no silent argument-count ceiling)

**Implementation approach (written second, to make tests pass):**

Spec defines:
- `Exit_Status` as `range 0 .. 255` (POSIX truth at the type level)
- `Command_Result` discriminated record on `Exit_State` with state-specific fields (`Error_Code`, `Exit_Status`, `Signal`) plus shared `Output`/`Error_Output`
- `Run_Command(Program, Args, Err_To_Out)` — spawn with argument list
- `Run_Command_Shell(Command, Err_To_Out)` — spawn `/bin/sh -c Command`

Body implements:
- An internal `Argument_Owner` controlled type owning a `Vectors` of `Spoon.Argument_Access` so deallocation runs even on exception unwind. The type lives in a nested private package so its `Finalize` override is a dispatching primitive.
- For each argument, allocate via `new Spoon.Argument'(Spoon.To_Argument(...))` and append. Build the `Spoon.Argument_Array` from the vector at call time.
- Call `Spoon.Spawn` (the blocking overload that returns `Result`).
- Map `Spoon.Result` to `Command_Result`, extracting captured stdout/stderr from a `Spoon.Output.Text_Capturer`.
- For `Err_To_Out = True`: return only `Output` (Spoon captures both; we merge stderr content into stdout field).
- For `Err_To_Out = False`: return `Output` and `Error_Output` separately.
- Log invocation at Debug ("Spawning <program> with N args") before spawn, then log result by state: Info on Exited(0), Warning on Exited(non-zero), Error on Crashed/Terminated/spawn-Error.
- For `Run_Command_Shell`: call `Run_Command` with program `/bin/sh` and args `["-c", Command]`.
- Add a header comment on `Run_Command` warning that the call is blocking with no timeout/bound — see Q2 issue.

**Patterns:**
- Discriminated record style from AGENTS.md (`Deploy_Result` pattern in `podmander-messages-deploy_results.ads`)
- Logging via `Podmander.Logging` as used in Deployer and Status_Collector
- Unbounded_String usage as in existing agent packages
- Test registration in test_runner following `Podmander.Messages_Tests` / `Podmander.Logging_Tests`
- Use only commands guaranteed available in the distrobox: `echo`, `false`, `sh`
- NOT mocked — we're testing against real process spawning (Host_Command *is* the driver abstraction over Spoon)

**Verification:** All tests pass. `alr build` succeeds.

**Planning-time unknowns:**
- How Spoon handles `posix_spawn` errors for non-existent executables — Resolved during TDD: returns `Error` variant.

---

### Unit 3: Add Result_Code to protocol (TDD)

**Goal:** Create the `Podmander.Messages.Result_Codes` package and add `Result_Code` to the wire format of both `Deploy_Result` and `Status_Response`. Status_Response is also split into separate `Containers` and `Error_Message` fields rather than an overloaded single string.

**Requirements trace:** R7

**Dependencies:** None at the type level, but Deployer and Status_Collector constructor sites change with the record shape, so this unit also touches those files for compile correctness. Deferred behavioural integration (mapping Result.State → Result_Code) lands in Units 5 and 6.

**Files:**
- `src/protocol/podmander-messages-result_codes.ads` — new package defining `Result_Code` enum and its wire encoding/decoding helpers
- `src/protocol/podmander-messages-result_codes.adb`
- `src/protocol/podmander-messages-deploy_results.ads` — add `Code : Result_Code` to flat record
- `src/protocol/podmander-messages-deploy_results.adb` — update `Encode`/`Decode` for new wire format with result_code frame
- `src/protocol/podmander-messages-status_responses.ads` — add `Code` field; split `Payload` into `Containers` + `Error_Message`
- `src/protocol/podmander-messages-status_responses.adb` — update `Encode`/`Decode`
- `src/agent/podmander-agent-deployer.adb` — adjust constructors to the new shape (still using simple Ok/Failed pending Unit 5)
- `src/agent/podmander-agent-status_collector.adb` — same
- `src/controller/podmander-controller-message_handlers.adb` — update Status_Response handler to read split fields
- `tests/podmander-messages_tests.adb` — update round-trip tests for both message types, add tests for non-Ok result codes

**TDD sequence:**

1. **Red:** Write `Result_Codes` spec. Update round-trip tests for Deploy_Result and Status_Response to expect the new flat shape. Add tests for non-Ok codes (Failed, Unavailable). Tests fail with current types.
2. **Green:** Implement Result_Codes body. Add `Code` to both message types. Split Status_Response payload. Update Encode/Decode. Adjust constructor sites. Tests pass.
3. **Clean up:** Remove dead code from old wire format.

**Approach:**

`Result_Codes` package:
```ada
type Result_Code is
  (Ok,                --  Operation succeeded
   Failed,             --  Operation failed (permanent, don't retry)
   Unavailable,        --  Target service/tool not reachable (transient, retry)
   Invalid_Argument,   --  Bad input from controller
   Internal);          --  Agent-side bug / unexpected state

function Encode_Code (Code : Result_Code) return String;
--  Returns the wire representation: "OK", "FAILED", etc.

function Decode_Code (S : String) return Result_Code;
--  Raises Decode_Error for unknown strings.
```

`Deploy_Result` (flat record):
```ada
type Deploy_Result is new Deploy_Result_Type with record
   Code          : RC.Result_Code := RC.Ok;
   Service_Name  : Unbounded_String;
   Error_Message : Unbounded_String;   --  empty when Code = Ok
end record;
```
Wire: `"deploy_ack"` + `Encode_Code(Code)` + service_name + error_message

`Status_Response` (flat record, two payload fields):
```ada
type Status_Response is new Status_Response_Type with record
   Code          : RC.Result_Code := RC.Ok;
   Containers    : Unbounded_String;   --  tab-separated name/status when Ok
   Error_Message : Unbounded_String;   --  populated when Code /= Ok
end record;
```
Wire: `"status_ack"` + `Encode_Code(Code)` + containers + error_message

**Patterns:**
- Flat record + `Code` field, not a discriminated record. Discriminated records were rejected: every variant carried the same fields, so discrimination bought no structural benefit and complicated construction.
- Message encode/decode pattern from existing message types
- `Result_Code'Image` / `Result_Code'Value` for wire serialisation

**Verification:** All message round-trip tests pass. `alr build` succeeds.

---

### Unit 4: Result_Mapping child package (TDD)

**Goal:** Provide a single function that maps `Command_Result` to `Result_Code`, so consumers do not duplicate the mapping logic.

**Requirements trace:** R7 (consumer-side)

**Dependencies:** Unit 2, Unit 3

**Files:**
- `tests/podmander-agent-host_command-result_mapping_tests.ads` — test spec (write first)
- `tests/podmander-agent-host_command-result_mapping_tests.adb` — test body (write first)
- `tests/test_runner.adb` — register new suite
- `src/agent/podmander-agent-host_command-result_mapping.ads` — new spec
- `src/agent/podmander-agent-host_command-result_mapping.adb` — new body

**Test scenarios:**
- Test_Exited_Zero_Maps_Ok: `Exited(0)` → `Ok`
- Test_Exited_Nonzero_Maps_Failed: `Exited(1)` → `Failed`
- Test_Error_Maps_Unavailable: `Error` → `Unavailable`
- Test_Crashed_Maps_Internal: `Crashed` → `Internal`
- Test_Terminated_Maps_Internal: `Terminated` → `Internal`

**Approach:** A single `function To_Result_Code (Result : Command_Result) return RC.Result_Code` with a case statement. The package spec carries a comment recording the deliberate coarse bucketing (errno detail and signal numbers are dropped) so future maintainers know it was a conscious YAGNI call rather than an oversight.

**Verification:** All five mapping tests pass. `alr build` succeeds.

---

### Unit 5: Refactor Deployer to use Host_Command + Result_Mapping

**Goal:** Replace `GNAT.OS_Lib.Spawn` calls in Deployer with `Host_Command.Run_Command`, and use `Result_Mapping.To_Result_Code` for the protocol mapping.

**Requirements trace:** R1, R2, R4, R7

**Dependencies:** Unit 2, Unit 3, Unit 4

**Files:**
- `src/agent/podmander-agent-deployer.adb`

**Verification approach:** Refactor verified by `alr build` and the broader test suite. Full functional tests of `Execute_Deploy` require systemd in the environment and are integration-test territory (gated per AGENTS.md). Unit-level: confirm the build is clean, no `GNAT.OS_Lib` import remains for spawn, and the catch-all exception handler logs `Exception_Name` alongside `Exception_Message`.

**Approach:**
- Replace Daemon_Reload block: call `Run_Command("/usr/bin/systemctl", ["--user", "daemon-reload"], Err_To_Out => True)`
- Replace Start_Service block: call `Run_Command("/usr/bin/systemctl", ["--user", "start", Service_Name & ".service"], Err_To_Out => True)`
- Use `Result_Mapping.To_Result_Code (Result)` for the `Code` field.
- Remove manual `Argument_List` allocation and `Free` calls
- Keep quadlet file writing unchanged (out of scope per requirements)
- Catch-all `when E : others` handler logs `Exception_Name (E) & ": " & Exception_Message (E)` and returns `Code => Internal` with the same detail in `Error_Message`.

**Patterns:** Existing Deployer error-return shape; consumer of `Result_Mapping`.

**Verification:** `alr build` succeeds. No `GNAT.OS_Lib` in Deployer. Existing test suite still passes.

---

### Unit 6: Refactor Status_Collector to use Host_Command + Result_Mapping

**Goal:** Replace temp-file hack in Status_Collector with `Host_Command.Run_Command`, eliminating the race condition and shell invocation, and use `Result_Mapping.To_Result_Code`.

**Requirements trace:** R1, R2, R4, R7

**Dependencies:** Unit 2, Unit 3, Unit 4

**Files:**
- `src/agent/podmander-agent-status_collector.adb`

**Verification approach:** Same as Unit 5 — refactor verified by `alr build` and the broader test suite. Full functional tests of `Collect_Status` require podman in the environment.

**Approach:**
- Call `Run_Command("/usr/bin/podman", ["ps", "--format", "{{.Names}} {{.Status}}"], Err_To_Out => False)`
- Map via `Result_Mapping.To_Result_Code`. On `Ok`, populate `Containers` with `Result.Output`. On non-Ok, populate `Error_Message` with `Result.Error_Output` (or `Output` when stderr is empty).
- Remove temp-file path constant, file open/read/close, and delete operations
- Remove `/bin/sh -c` shell invocation entirely
- Catch-all `when E : others` handler logs `Exception_Name (E) & ": " & Exception_Message (E)`.

**Verification:** `alr build` succeeds. No reference to `/tmp/podmander-status.txt`, `GNAT.OS_Lib`, or `Ada.Text_IO` in the file. Existing test suite passes.

---

## Quality Bar Checklist

- [x] Every unit has a requirements trace (Unit 1 honestly marked as a prerequisite, not a requirement satisfier)
- [x] Dependencies form a DAG (1 → 2; 3; 2 + 3 → 4; 2 + 3 + 4 → 5; 2 + 3 + 4 → 6)
- [x] Every unit lists its test scenarios; Units 5 and 6 are explicitly marked as build-and-suite-verified refactors rather than TDD, since their behavioural tests need systemd/podman
- [x] No unit touches >10 files
- [x] No more than 2 new abstractions introduced per unit (Unit 2: Command_Result + Run_Command; Unit 3: Result_Code + flat protocol records; Unit 4: To_Result_Code)
- [x] Every planning-time unknown is classified as resolved or deferred (Q1 resolved, Q2 deferred to a tracked issue)
- [x] TDD discipline: Units 2, 3, 4 write tests before implementation. Units 5 and 6 are refactors, not new behaviour.
