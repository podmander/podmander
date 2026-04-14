# Agent Heartbeat Implementation Plan

**Requirements:** [agent-heartbeat-requirements.md](agent-heartbeat-requirements.md)
**Date:** 2026-04-12

## High-Level Architecture

Single Alire crate (`podmander`) producing two executables: `pod_controller`
and `pod_agent`. Shared types and protocol logic live in library packages under
`Podmander.*`. Communication uses `czmq_ada` with ROUTER/DEALER sockets and
multi-frame messages.

```
podmander/
  alire.toml
  podmander.gpr
  src/
    pod_controller.adb          -- Controller main
    pod_agent.adb               -- Agent main
    podmander.ads               -- Root package
    podmander-messages.ads/adb  -- Message protocol (frame encoding/decoding)
    podmander-types.ads         -- Shared types (Connection_State, Agent_Info)
  tests/
    podmander-messages_tests.adb
```

## Implementation Units

### Unit 1: Project Scaffolding

**Goal:** Alire crate that builds two executables and depends on `czmq_ada`.

**Requirements trace:** R1

**Dependencies:** None (first unit)

**Files:**
- `alire.toml` — crate metadata, `czmq_ada` dependency
- `podmander.gpr` — GPR project file with two mains
- `src/podmander.ads` — root package spec (empty body)
- `src/pod_controller.adb` — stub main, prints "Controller starting"
- `src/pod_agent.adb` — stub main, prints "Agent starting"

**Approach:** Initialize with `alr init`, add `czmq_ada` dependency, configure
GPR for two executables. Verify both build and run inside `ada_dev` distrobox.

**Test scenarios:**
- [ ] `alr build` succeeds without errors
- [ ] `./bin/pod_controller` prints startup message and exits
- [ ] `./bin/pod_agent` prints startup message and exits

**Verification:** Both executables build and produce output.

**Planning-time unknowns:**
- Exact GPR syntax for multiple mains in one project — Deferred to Implementation

---

### Unit 2: Shared Types and Message Protocol

**Goal:** Define the message protocol as Ada types with encode/decode to CZMQ
multi-frame messages.

**Requirements trace:** R4, R5

**Dependencies:** Unit 1

**Files:**
- `src/podmander-types.ads` — `Connection_State` enum, `Agent_Info` record
- `src/podmander-messages.ads` — Message type hierarchy (tagged types)
- `src/podmander-messages.adb` — Encode/decode to CZMQ frames
- `tests/podmander-messages_tests.adb` — Round-trip encode/decode tests

**Approach:** Define an interface type `Protocol_Message` with `Encode` (to
`CZMQ.Messages.Message`) and a `Decode` function (from `CZMQ.Messages.Message`).
Concrete tagged types for each message kind:

- `Register_Request` — agent name
- `Register_Response` — assigned node ID
- `Heartbeat_Message` — agent ID, timestamp

Use the first frame as a message type discriminator string (`"register"`,
`"registered"`, `"heartbeat"`), subsequent frames carry payload fields.

Note: ROUTER sockets automatically prepend a routing identity frame. The
protocol layer does not need to handle this — CZMQ manages it. But the
controller must read the identity frame before decoding the protocol message.

**Test scenarios:**
- [ ] Round-trip encode/decode of `Register_Request`
- [ ] Round-trip encode/decode of `Register_Response`
- [ ] Round-trip encode/decode of `Heartbeat_Message`
- [ ] Decode of unknown message type returns error/raises exception

**Verification:** All tests pass via `alr test` (or direct executable run).

**Planning-time unknowns:**
- Whether AUnit is available as an Alire crate or needs manual setup — Deferred to Implementation

---

### Unit 3: Controller Core

**Goal:** Controller binds ROUTER socket, accepts registrations, logs
heartbeats, and detects timeouts.

**Requirements trace:** R2, R4, R6, R7, R8

**Dependencies:** Unit 2

**Files:**
- `src/podmander-controller.ads` — Controller tagged type spec
- `src/podmander-controller.adb` — Main loop, registration, timeout logic
- `src/pod_controller.adb` — Updated main: parse CLI args, create and run controller

**Approach:** `Controller` is a tagged type holding:
- A CZMQ ROUTER socket
- A map of `Agent_Info` records keyed by agent ID (using `Ada.Containers.Indefinite_Hashed_Maps`)
- Configuration (bind address, timeout multipliers)

Main loop uses `zpoller_wait` (low-level) with a timeout equal to the heartbeat
interval. On each iteration:
1. If a message arrived: read identity frame, decode protocol message, dispatch
2. On `Register_Request`: add agent to map, send `Register_Response`
3. On `Heartbeat_Message`: update agent's last-seen timestamp, log
4. After poll: scan agent map for timeouts, log state transitions

Heartbeats from unregistered agents are logged as warnings and discarded.

Tests use in-process integration: create Controller and Agent objects connected
via localhost within AUnit tests.

**Test scenarios:**
- [ ] Controller starts and binds to configured address
- [ ] Receiving a register message adds agent to tracking map
- [ ] Receiving a heartbeat updates last-seen timestamp
- [ ] Agent missing 2x interval transitions to unresponsive
- [ ] Agent missing 3x interval transitions to disconnected
- [ ] Duplicate registration from same agent is handled gracefully
- [ ] Heartbeat from unregistered agent logs warning and is discarded

**Verification:** Controller runs, accepts connections from `pod_agent`, logs
registration and heartbeat events to stdout.

**Planning-time unknowns:**
- Whether `czmq_ada` receive has a timeout option or if low-level `zpoller_wait` is needed — Deferred to Implementation (check API, fall back to poller if needed)

---

### Unit 4: Agent Core

**Goal:** Agent connects DEALER socket, sends registration, heartbeats
periodically, implements connection state machine.

**Requirements trace:** R3, R4, R5, R9

**Dependencies:** Unit 2

**Files:**
- `src/podmander-agent.ads` — Agent tagged type spec
- `src/podmander-agent.adb` — Connection state machine, heartbeat loop
- `src/pod_agent.adb` — Updated main: parse CLI args, create and run agent

**Approach:** `Agent` is a tagged type holding:
- A CZMQ DEALER socket
- Current `Connection_State` (Disconnected, Enrolling, Connected)
- Configuration (controller address, agent name, heartbeat interval)

State machine:
- **Disconnected:** connect DEALER to controller, send `Register_Request`,
  transition to Enrolling
- **Enrolling:** wait for `Register_Response` (with timeout). On success:
  store node ID, transition to Connected. On timeout: disconnect, wait with
  exponential backoff, retry from Disconnected
- **Connected:** send `Heartbeat_Message` every interval. If send fails,
  transition to Disconnected

Uses `zpoller_wait` with heartbeat interval as timeout to balance receiving
messages and sending heartbeats.

Tests use in-process integration: connect Agent to a Controller on localhost
within AUnit tests.

**Test scenarios:**
- [ ] Agent connects and sends register message
- [ ] Agent transitions to Connected on successful registration
- [ ] Agent sends heartbeats at configured interval after registration
- [ ] Agent retries with backoff on registration timeout
- [ ] Agent reconnects on connection loss

**Verification:** Agent registers with running controller, heartbeats appear in
controller logs at expected interval.

**Planning-time unknowns:** None

---

### Unit 5: CLI Arguments and Signal Handling

**Goal:** Both executables accept CLI arguments and shut down cleanly on
SIGINT/SIGTERM.

**Requirements trace:** R10, R11

**Dependencies:** Unit 3, Unit 4

**Files:**
- `src/pod_controller.adb` — CLI parsing, signal handler setup
- `src/pod_agent.adb` — CLI parsing, signal handler setup

**Approach:** Use `Ada.Command_Line` for minimal argument parsing (positional
or `--flag=value`). No external CLI framework needed for this scope.

Arguments:
- `pod_controller`: `--bind=tcp://*:5555` (default), `--interval=30`
- `pod_agent`: `--connect=tcp://localhost:5555` (default), `--name=agent-1`,
  `--interval=30`

For signal handling, use `GNAT.Ctrl_C` or POSIX signal handlers to set a
shutdown flag checked by the main loop.

**Test scenarios:**
- [ ] Default arguments produce working configuration
- [ ] Custom `--bind` / `--connect` addresses are used
- [ ] Custom `--interval` changes heartbeat timing
- [ ] SIGINT causes clean shutdown (socket closed, exit 0)
- [ ] Invalid arguments produce a usage message

**Verification:** Both executables respond to CLI flags and shut down cleanly on
Ctrl-C.

**Planning-time unknowns:** None

---

## Quality Bar Checklist

- [x] Every unit has a requirements trace
- [x] Dependencies form a DAG (1 → 2 → 3,4 → 5)
- [x] Every unit has at least 3 test scenarios
- [x] No unit touches >8 files
- [x] No more than 2 new abstractions introduced per unit
- [x] Every planning-time unknown is classified as blocker or deferred
- [x] Handoff completeness: an engineer knows what to build from this plan
  without inventing product behavior
