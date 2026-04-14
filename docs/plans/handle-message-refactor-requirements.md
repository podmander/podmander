# Handle_Message Refactor Requirements

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-14
**Tracking:** podmander/podmander#1

## Problem Frame

`Podmander.Controller.Handle_Message` currently receives a CZMQ message, peels
the Router identity frame, decodes the payload, and then inline-handles each
concrete message kind (`Register_Request`, `Heartbeat_Message`, unknown,
`Decode_Error`) in a single `if/elsif` chain. Every new protocol message adds
another branch, duplicates its own error-logging surface, and grows the
procedure's responsibility surface.

Podmander is about to add more operations messages (deploy commands,
status queries, etc.), so the cost of leaving this structure grows linearly
with the protocol. The refactor introduces a dispatch mechanism that maps
each message type to its handler without the message types knowing the
handlers, and without `Podmander.Messages` depending on
`Podmander.Controller`.

## Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R1 | `Podmander.Messages` declares a `Message_Handler` interface with one `Handle_*` primitive per concrete message type. | Must Have | Compile-time exhaustive: new message kinds force new handler methods. |
| R2 | `Protocol_Message` gains one abstract primitive `Dispatch_To (Self; H : in out Message_Handler'Class)`. Each concrete message overrides it with a one-line body that calls the matching `H.Handle_*`. | Must Have | Message routes; it does not handle itself. |
| R3 | `Podmander.Controller` provides a concrete `Message_Handler` implementation that operates on `Controller_Instance` state. | Must Have | Lives in the controller, not in messages. |
| R4 | `Handle_Message` shrinks to: receive, timeout check, peel identity, decode, call `Decoded.Dispatch_To (Handler)`. Unknown-kind and `Decode_Error` paths stay centralized in `Handle_Message`. | Must Have | Handler implementations contain no fallback/dispatch logic. |
| R5 | `Podmander.Messages` does not gain any dependency on `Podmander.Controller`. | Must Have | Cycle-free; enforced by build. |
| R6 | Existing observable behavior is preserved: registration creates an agent record and sends a `Register_Response`; heartbeat updates `Last_Seen`, logs reconnection when state transitions from non-`Registered`, and warns on unknown agent; malformed messages log a warning; unexpected message kinds log a warning including the sender identity. | Must Have | Verified via unit tests on the handler. |
| R7 | A unit test package covers the `Message_Handler` implementation: registration happy path, heartbeat happy path, heartbeat from unknown agent, reconnection state transition. | Must Have | Uses a seam that does not require a live ZMQ socket. |
| R8 | Controller identity-frame handling (peel on receive, echo on reply) remains in `Handle_Message` / `Handle_Register_Request`. | Must Have | Router semantics unchanged. |

## Success Criteria

- `alr build` succeeds with zero warnings on `podmander` and `podmander_tests`.
- `alr test` (AUnit) passes; new tests in requirement R7 exercise each handler path.
- `Handle_Message` body is ≤ 25 lines and contains no `if Decoded in ...`
  chain.
- Adding a hypothetical new message kind requires: one new type in
  `Podmander.Messages`, one `Handle_*` method on `Message_Handler`, one
  override of `Dispatch_To`, and one implementation in the controller's
  handler — and the compiler fails until all four exist.

## Scope Boundaries

**In scope:**
- Refactor of `Handle_Message` and supporting handler dispatch infrastructure.
- New `Message_Handler` interface in `Podmander.Messages`.
- New `Dispatch_To` primitive on `Protocol_Message` and overrides on each
  concrete message.
- New concrete handler type in `Podmander.Controller` (body-local if possible).
- Unit tests for the new handler type.

**Out of scope:**
- Adding new message kinds (deploy, status, etc.) — requirement R1 only
  covers today's kinds: `Register_Request`, `Heartbeat_Message`.
  `Register_Response` is controller→agent and not inbound, so no handler.
- Changing message wire format or `Podmander.Messages.Decode`.
- Changing CZMQ socket topology, polling loop, or timeout handling.
- Replacing `Ada.Text_IO.Put_Line` logging with a structured logger.
- Integration tests that exercise a real ZMQ socket.

## Key Decisions

| Decision | Chosen | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Dispatch style | Visitor pattern, renamed `Message_Handler` + `Dispatch_To` | Compile-time exhaustive; no package cycle; each concrete message is one-line routing only (SRP holds); scales to new operations (audit, metrics) as new `Message_Handler` implementations. | (1) Private handler procs + `if/elsif in X` dispatch — doesn't scale, was the current problem. (2) Message-has-Handle primitive — violates SRP (message handles itself). (3) `Ada.Tags.Tag`-keyed runtime registry — runtime binding, loses compile-time exhaustiveness. (4) Child package `Podmander.Messages.Dispatch` — adds a package just to wire dependencies. |
| Interface naming | `Message_Handler` / `Handle_*` / `Dispatch_To` | Names *what it does*, not *what pattern it is*. Reads naturally at the call site. | `Message_Visitor` / `Visit_*` / `Accept_Visitor` — requires knowing GoF. |
| Handler location | Concrete `Message_Handler` impl in `Podmander.Controller` body (or a private child if spec exposure is needed) | Keeps controller state access private; no public API surface added beyond what already exists. | Public child package — unnecessary visibility. |
| Fallback paths | `Decode_Error` and unknown-kind warnings stay in `Handle_Message` | The handler interface is for *known, decoded* messages; fallbacks are a property of the dispatch step, not of any handler. | Adding `Handle_Unknown` to the interface — pollutes the contract with a non-message case. |

## Outstanding Questions

| # | Question | Impact if Wrong | Owner |
|---|----------|-----------------|-------|
| Q1 | Should the concrete handler type be declared in the controller's `.adb` body (private, minimal surface) or exposed in a private child `Podmander.Controller.Message_Handlers`? | Private body is simpler; private child is easier to test directly. If testability forces exposure, units must account for it. | Resolve during Phase 4 (Structure) once test approach is concrete. |
| Q2 | Do handler methods need access to the Router `Identity` string (needed today for `Register_Request` reply routing)? If so, is it passed as a field on the handler object before dispatch, or as an extra parameter on every `Handle_*` method? | Passing on every method pollutes the interface. Storing on the handler is simpler but makes the handler stateful-per-message. | Decide in Phase 4; lean toward stateful-per-message (set `Handler.Identity := Identity` before `Dispatch_To`). |
