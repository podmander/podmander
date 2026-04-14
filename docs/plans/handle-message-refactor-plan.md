# Handle_Message Refactor — Implementation Plan

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-14
**Tracking:** podmander/podmander#1
**Requirements:** `docs/plans/handle-message-refactor-requirements.md`

## Architecture

### Component boundaries after refactor

```
Podmander.Messages                 Podmander.Controller
--------------------               ----------------------------
Protocol_Message (interface)       Controller_Instance
  + Dispatch_To (primitive)        Controller_Handler (Message_Handler impl,
Message_Handler (interface)          body-local, holds Controller_Instance
  + Handle_Register_Request          reference + current Identity)
  + Handle_Heartbeat               Handle_Message
Register_Request                     - receive
  + Dispatch_To override             - timeout short-circuit
Heartbeat_Message                    - peel Identity, decode
  + Dispatch_To override             - set Handler.Identity
Register_Response                    - Decoded.Dispatch_To (Handler)
  (outbound, no Dispatch_To)         - catch Decode_Error for malformed log
```

### Data flow

1. `Handle_Message` reads one frame group from the Router socket.
2. Identity frame peeled off, payload decoded to `Protocol_Message'Class`.
3. `Handle_Message` stores the identity on its `Controller_Handler` instance.
4. `Decoded.Dispatch_To (Handler)` — polymorphic call, routes to the right
   `Handle_*` method at compile-time-checked dispatch.
5. Handler method mutates `Controller_Instance.Agents`, optionally sends a
   reply through `Controller_Instance.Socket.all`.

### Dependency direction

`Podmander.Controller` → `Podmander.Messages` only. No reverse dependency.
Verified at build by the compiler refusing any `with Podmander.Controller`
in `Podmander.Messages`.

## Implementation Units

### Unit 1: Introduce `Message_Handler` interface and `Dispatch_To` primitive in `Podmander.Messages`

**Goal:** Add the dispatch surface to the messages package without any
dependency on the controller.

**Requirements trace:** R1, R2, R5.

**Dependencies:** none.

**Files:**
- `src/podmander-messages.ads` — add `Message_Handler` interface with
  `Handle_Register_Request` and `Handle_Heartbeat` abstract primitives. Add
  abstract `Dispatch_To` primitive to `Protocol_Message`. Add `overriding`
  declarations of `Dispatch_To` on `Register_Request` and
  `Heartbeat_Message`. `Register_Response` does NOT get `Dispatch_To`
  because it's outbound-only — to keep the interface honest, either
  (a) split the hierarchy into `Inbound_Message` / `Outbound_Message`, or
  (b) give `Register_Response.Dispatch_To` a body that raises
  `Program_Error`. Choose (b): minimum change, and `Decode` never produces a
  `Register_Response` from inbound traffic, so the raise is unreachable in
  practice. Document this in a one-line comment.
- `src/podmander-messages.adb` — implement the three `Dispatch_To` bodies.
  Each concrete inbound message body is one line:
  `H.Handle_Register_Request (Self);` / `H.Handle_Heartbeat (Self);`.
  `Register_Response.Dispatch_To` raises `Program_Error` with message
  `"Register_Response is outbound-only"`.

**Approach:**

```ada
--  In podmander-messages.ads, after Protocol_Message declaration:
type Message_Handler is interface;

procedure Handle_Register_Request
  (H : in out Message_Handler;
   M : Register_Request) is abstract;

procedure Handle_Heartbeat
  (H : in out Message_Handler;
   M : Heartbeat_Message) is abstract;

--  On Protocol_Message:
procedure Dispatch_To
  (Self : Protocol_Message;
   H    : in out Message_Handler'Class) is abstract;

--  On each concrete message, add:
overriding procedure Dispatch_To
  (Self : Register_Request;
   H    : in out Message_Handler'Class);
--  etc. for Heartbeat_Message and Register_Response.
```

**Patterns:** Follows the existing `overriding procedure Encode` pattern
already established for each concrete message in `podmander-messages.ads`.
Interface types and `is abstract` primitives are standard Ada 2012+.

**Test scenarios:**
- [ ] Happy path: a spy `Message_Handler` records one call to
  `Handle_Register_Request` when `Register_Request.Dispatch_To` is invoked.
- [ ] Happy path: same for `Heartbeat_Message` → `Handle_Heartbeat`.
- [ ] Error path: `Register_Response.Dispatch_To` raises `Program_Error`.
- [ ] Edge case: calling `Dispatch_To` via `Protocol_Message'Class` (the
  way `Handle_Message` will) dispatches polymorphically to the right method.

**Verification:** `alr build` succeeds. New tests in Unit 3 (below) pass.

**Planning-time unknowns:** none.

---

### Unit 2: Refactor `Handle_Message` to delegate via `Message_Handler`

**Goal:** Replace the inline `if Decoded in X` chain with a single
`Dispatch_To` call, extracting per-kind logic into `Controller_Handler`.

**Requirements trace:** R3, R4, R6, R8.

**Dependencies:** Unit 1.

**Files:**
- `src/podmander-controller.adb` — add a body-local `Controller_Handler`
  tagged type that implements `Podmander.Messages.Message_Handler`. Holds
  a reference to the enclosing `Controller_Instance` and the current
  `Identity` for the message in flight. Implements
  `Handle_Register_Request` (body = current register-handling code,
  identity-framed reply included, with the reply `Send` guarded on
  `H.Ctrl.Socket /= null` so the handler is callable from tests without a
  live socket) and `Handle_Heartbeat` (body = current
  heartbeat-handling code). Rewrite `Handle_Message` to: receive,
  timeout check, peel identity, decode, set `Handler.Identity`, call
  `Decoded.Dispatch_To (Handler)`. Keep the `Decode_Error` exception
  handler and the "unexpected kind" warning in `Handle_Message`. The
  "unexpected kind" path is reached by catching the `Program_Error` from
  `Register_Response.Dispatch_To` — no, that's wrong: decode never produces
  `Register_Response`, so no dispatched handler is a genuine "unexpected."
  Instead, catch any concrete unknown via the fact that `Decode` already
  raises `Decode_Error` on unknown kinds; so the "unexpected kind" branch
  in the current code is effectively unreachable today. Remove it, and
  let the `Decode_Error` handler cover all malformed/unknown cases with a
  single warning message.

  **Observable behavior change:** log text merges from two distinct
  warnings ("WARNING: Unexpected message from X" / "WARNING: Malformed
  message from X") into a single "WARNING: Malformed message from X".
  Accepted as a cosmetic change; revisit when structured logging is
  introduced.

**Approach:**

```ada
--  Inside package body Podmander.Controller:

type Controller_Handler is limited new Podmander.Messages.Message_Handler with
   record
      Ctrl     : access Controller_Instance;
      Identity : Unbounded_String;
   end record;

overriding procedure Handle_Register_Request
  (H : in out Controller_Handler;
   M : Podmander.Messages.Register_Request);

overriding procedure Handle_Heartbeat
  (H : in out Controller_Handler;
   M : Podmander.Messages.Heartbeat_Message);

procedure Handle_Message (Self : in out Controller_Instance) is
   Msg     : CZMQ.Messages.Message;
   Status  : CZMQ.Messages.Receive_Status;
   --  Safe: Handler is stack-local to Handle_Message and cannot outlive
   --  Self. Unchecked_Access is used only to avoid aliasing aspects here.
   Handler : Controller_Handler := (Ctrl => Self'Unchecked_Access,
                                    Identity => Null_Unbounded_String);
begin
   CZMQ.Messages.Receive (Self.Socket.all, Msg, Status);
   if Status = CZMQ.Messages.Timeout then
      return;
   end if;

   Handler.Identity := To_Unbounded_String (Msg.Pop_String);
   declare
      Decoded : constant Podmander.Messages.Protocol_Message'Class :=
        Podmander.Messages.Decode (Msg);
   begin
      Decoded.Dispatch_To (Handler);
   exception
      when Podmander.Messages.Decode_Error =>
         Ada.Text_IO.Put_Line
           ("WARNING: Malformed message from "
            & To_String (Handler.Identity));
   end;
end Handle_Message;
```

**Patterns:** Body-local tagged type matches the Ada idiom for
implementation-only polymorphism. `Self'Unchecked_Access` is the standard
way to reference the enclosing instance inside a body-local helper. The
identity-frame peel + echo pattern is preserved from the original code.

**Test scenarios:**
- [ ] Happy path: register flow — a constructed `Register_Request`
  dispatched via `Controller_Handler` adds an agent to `Self.Agents` and
  sends a reply message on a mock/captured socket path.
- [ ] Happy path: heartbeat flow — a constructed `Heartbeat_Message`
  for a known agent updates `Last_Seen` and preserves state.
- [ ] Edge case: heartbeat for unknown agent — logs warning, does not
  mutate `Self.Agents`.
- [ ] Edge case: heartbeat transitions agent from non-`Registered` state
  back to `Registered` and logs reconnection.
- [ ] Error path: `Handle_Message` catches `Decode_Error` from a malformed
  inbound message and logs a warning.

**Verification:** `alr build` succeeds. `Handle_Message` body is ≤ 25
lines. No `if Decoded in ...` chain remains.

**Planning-time unknowns:**
- *Deferred to Planning:* Socket-mocking strategy for test scenarios 1 and
  2. Options: (a) add a minimal fake socket type; (b) scope handler tests
  to paths that don't touch `Self.Socket` (heartbeat scenarios 2–4 only),
  and cover the register reply indirectly via an integration test later.
  Lean toward (b) for this refactor to avoid introducing a socket
  abstraction that's out of scope; the register reply logic is verbatim
  from the current code and hasn't changed semantically.

---

### Unit 3: Unit tests for `Dispatch_To` routing and handler behavior

**Goal:** Lock in the dispatch contract and handler behavior so future
message additions can't regress routing or heartbeat semantics.

**Requirements trace:** R6, R7.

**Dependencies:** Unit 1 (for the interface), Unit 2 (for the handler).

**Files:**
- `tests/podmander-controller_tests.ads` — new AUnit test package
  `Podmander.Controller_Tests` mirroring the existing
  `Podmander.Messages_Tests` style.
- `tests/podmander-controller_tests.adb` — implements the test scenarios
  below.
- `tests/test_runner.adb` — register the new test suite alongside
  `Podmander.Messages_Tests`.

**Approach:**

1. Define a test-only `Spy_Handler` tagged type implementing
   `Message_Handler` inside the test body. Records method name + a copy of
   the received message. Use this to verify that
   `Register_Request.Dispatch_To` calls `Handle_Register_Request` and
   `Heartbeat_Message.Dispatch_To` calls `Handle_Heartbeat`. Also verify
   that calling `Dispatch_To` through `Protocol_Message'Class` still
   dispatches correctly (polymorphism assertion).
2. Test `Register_Response.Dispatch_To` raises `Program_Error`.
3. For `Controller_Handler` behavior tests, expose a way to invoke the
   handler without a socket. Simplest: declare `Controller_Handler` and
   its two primitives in the package body as today (private), and add
   a body-local test seam — **no, tests can't reach body-local types**.
   Revised: promote `Controller_Handler` to a private child
   `Podmander.Controller.Message_Handlers` (`private package`). The child is
   visible to tests via `with Podmander.Controller.Message_Handlers` in the test
   file. Private-child visibility rules: in Ada, a private child is
   accessible to the parent and its other children, and to clients that
   have visibility to the parent's private part. For tests this is fine
   because the test program is a descendant-by-use, not a true client
   hierarchy — the practical path is to make it a **public child** with
   a clearly-named package (`Podmander.Controller.Message_Handlers`) documented
   as "exposed for testability."
4. Tests for heartbeat paths construct a `Controller_Instance`, seed
   `Self.Agents` directly, build a `Heartbeat_Message`, invoke
   `Handler.Handle_Heartbeat (Msg)` directly (bypassing socket), and
   assert on `Self.Agents` state.
5. Register reply test is deferred (see Unit 2's Deferred unknown).

**Patterns:** Follows `tests/podmander-messages_tests.adb` style — AUnit
`Test_Case` with `Register_Tests` routine. Use
`AUnit.Assertions.Assert`. Test naming: `Test_Dispatch_Register_Request`,
`Test_Dispatch_Heartbeat`, `Test_Dispatch_Response_Raises`,
`Test_Heartbeat_Unknown_Agent`, `Test_Heartbeat_Reconnect_Transition`.

**Test scenarios:**
- [ ] Happy path: `Spy_Handler` records `Handle_Register_Request` when
  `Register_Request.Dispatch_To` is invoked.
- [ ] Happy path: `Spy_Handler` records `Handle_Heartbeat` when
  `Heartbeat_Message.Dispatch_To` is invoked.
- [ ] Happy path: polymorphic dispatch — a `Protocol_Message'Class`
  variable holding a concrete message routes to the right method.
- [ ] Error path: `Register_Response.Dispatch_To` raises `Program_Error`.
- [ ] Edge case: `Handle_Heartbeat` for a registered agent updates
  `Last_Seen` (assert `Last_Seen` is after the pre-call clock reading).
- [ ] Edge case: `Handle_Heartbeat` for an unknown agent does not mutate
  `Self.Agents` (size unchanged).
- [ ] Edge case: `Handle_Heartbeat` transitions agent state from
  `Unresponsive` back to `Registered`.
- [ ] Happy path: `Handle_Register_Request` with a null-socket
  `Controller_Instance` adds the agent to `Self.Agents` (reply `Send`
  is guarded and skipped when `Self.Socket = null`).

**Verification:** `alr test` passes with the 8 new assertions.

**Planning-time unknowns:**
- *Resolve Before Planning:* Is `Controller_Handler` promoted to a public
  child package `Podmander.Controller.Message_Handlers`, or kept body-private
  with partial test coverage via the `Spy_Handler` only? Picking the
  former unblocks all 7 test scenarios; the latter covers scenarios 1–4
  but not 5–7. **Decision:** promote to public child
  `Podmander.Controller.Message_Handlers`. Testability > minimum surface here
  because R7 requires coverage of reconnection logic.

## Quality Bar Checklist

- [x] Every unit has a requirements trace.
- [x] Dependencies form a DAG: Unit 1 → Unit 2 → Unit 3 (Unit 3 also
  depends on Unit 1 directly). No cycles.
- [x] Every unit has ≥ 3 test scenarios (Unit 1: 4, Unit 2: 5, Unit 3: 7).
- [x] No unit touches > 8 files (Unit 1: 2, Unit 2: 1, Unit 3: 3).
- [x] No more than 2 new abstractions per unit (Unit 1 introduces 2:
  `Message_Handler` interface + `Dispatch_To` primitive. Unit 2
  introduces 1: `Controller_Handler`. Unit 3 introduces 1 test-only
  `Spy_Handler`).
- [x] Every planning-time unknown is classified (one Deferred in Unit 2,
  one Resolve-Before-Planning in Unit 3, resolved inline).
- [x] Handoff completeness: an engineer executing this plan needs to
  invent only implementation details (exact variable names, AUnit
  boilerplate). All product behavior is specified.
