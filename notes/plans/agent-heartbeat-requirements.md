# Agent Heartbeat Requirements

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-12

## Problem Frame

Podmander's architecture depends on reliable agent-controller communication as
the foundation for every higher-level feature (deployment, reconciliation, drift
detection). Before any of those features can be built, we need to prove that
the ZeroMQ-based ROUTER/DEALER pattern works in Ada, that two separate
executables can be scaffolded with Alire, and that a minimal registration and
heartbeat protocol functions end-to-end.

This slice intentionally omits encryption (CURVE), persistence (SQLite), join
tokens, and rich heartbeat payloads. It proves the communication pattern only.

## Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R1 | Project scaffolding: two Alire crates producing `pod_controller` and `pod_agent` executables | Must Have | Shared code in a common library crate |
| R2 | Controller binds a ZeroMQ ROUTER socket on a configurable address (default `tcp://*:5555`) | Must Have | Uses the `zeromq` Alire crate |
| R3 | Agent connects a ZeroMQ DEALER socket to a controller address (default `tcp://localhost:5555`) | Must Have | |
| R4 | Agent sends a `register` message on connect; controller responds with `registered` and assigns a node ID | Must Have | Hardcoded identity for now (agent name from CLI arg or default) |
| R5 | Agent sends periodic `heartbeat` messages after registration (default interval: 30s, configurable via CLI) | Must Have | Payload: agent ID, timestamp |
| R6 | Controller logs received heartbeats to stdout with agent ID and timestamp | Must Have | |
| R7 | Controller tracks registered agents in memory and detects missed heartbeats (2x interval = unresponsive, 3x = disconnected) | Must Have | |
| R8 | Controller logs agent state transitions (registered, unresponsive, disconnected) | Must Have | |
| R9 | Agent implements the connection state machine: DISCONNECTED -> ENROLLING -> CONNECTED | Should Have | With reconnect + exponential backoff on failure |
| R10 | Both executables accept `--bind`/`--connect` and `--interval` as CLI arguments | Should Have | Minimal CLI parsing, no full framework needed |
| R11 | Clean shutdown on SIGINT/SIGTERM for both executables | Should Have | |

## Success Criteria

- `pod_controller` starts and listens on a ZeroMQ ROUTER socket
- `pod_agent` connects, registers, and begins heartbeating
- Controller stdout shows registration and periodic heartbeat log lines
- When the agent is killed, the controller eventually logs it as unresponsive,
  then disconnected
- When the agent restarts, it re-registers and resumes heartbeating
- Both executables build cleanly inside the `ada_dev` distrobox via `alr build`

## Scope Boundaries

**In scope:**
- Alire project scaffolding (two executables, shared library)
- ZeroMQ ROUTER/DEALER communication
- Registration request/response
- Periodic heartbeat with agent ID and timestamp
- In-memory agent tracking on the controller
- Heartbeat timeout detection
- Basic CLI argument parsing
- Stdout logging

**Out of scope:**
- CURVE encryption (future slice)
- Join tokens and enrollment secrets (future slice)
- SQLite persistence (future slice)
- Service or infrastructure status in heartbeats (future slice)
- Supervisor loop and reconciliation (future slice)
- SSH data plane (future slice)
- Any config file parsing (TOML) (future slice)

## Key Decisions

| Decision | Chosen | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Transport | ZeroMQ via `czmq_ada` Alire crate | Matches spec, crate already exists | Plain TCP sockets (rejected: would need replacement later), `zeromq_ada` (lower-level binding) |
| Binary layout | Two separate executables from a single Alire crate | Simpler build, shared code naturally | Separate crates (rejected: unnecessary overhead for this stage) |
| State storage | In-memory only | Simplest possible; proves pattern without persistence overhead | SQLite (deferred to future slice) |
| Security | None (plain ZeroMQ) | Bare minimum scope; CURVE layered on next | CURVE from start (deferred: adds complexity to first slice) |
| Naming | `pod_controller`, `pod_agent` | Shortened from `podmander-*` for brevity | Full `podmander-controller` naming (rejected: verbose) |

## Outstanding Questions

All questions resolved:
- Q1: Crate is `czmq_ada` (v0.3.0)
- Q2: ROUTER/DEALER supported
- Q3: Single Alire crate with two executables
