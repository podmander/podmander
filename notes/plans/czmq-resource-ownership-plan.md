# CZMQ Resource Ownership — Implementation Plan

**Issue:** [#23 — Replace agent Socket/Certificate access types with controlled types](https://code.monospacementor.com/podmander/podmander/issues/23)
**Scope (bundled):** Same leak pattern in `Podmander.Controller` (see "Scope" below).
**Status:** Draft

## Problem

`Podmander.Agent.Agent_Instance` and `Podmander.Controller.Controller_Instance` hold their CURVE certificate, ZeroMQ socket, and (controller only) poller via plain access types. The CZMQ Ada bindings already declare `Certificate`, `Socket`, and `Poller` as `Ada.Finalization.Limited_Controlled` types whose `Finalize` releases the underlying CZMQ resource — but heap-allocating them and dropping the pointer never triggers `Finalize`. Result:

- **Agent:** every reconnect (`Self.Socket := null` after timeout / decode error / connection loss in `podmander-agent-connection.adb:89, 117, 156`) leaks one certificate (with embedded keys) and one socket. Long-running agents accumulate resources proportional to the number of disconnections.
- **Controller:** allocations in `Initialize` (`podmander-controller.adb:36-44`) live forever because `Controller_Instance` is never freed during normal operation. Resources are released only by process exit; nothing forces the CZMQ unbind/cleanup ordering before then.

## Approach

Path A — **scope-bound resource lifetime**. Hold CZMQ values directly (no access types) where their lifetime matches a natural scope:

- **Agent:** the certificate and socket exist for one connection cycle (connect → enrol → connected loop → disconnect). They become **local variables** of a new `Connection.Run_Cycle` procedure. The outer `Run` loop owns retry/backoff between cycles.
- **Controller:** the certificate and socket exist for the full process lifetime, so they become **direct `Limited_Controlled` fields** of `Controller_Instance`, populated by a factory function. The poller becomes a **local variable of `Run`** (its lifetime equals the run loop's).

Both call sites stop using `new`, drop the access-type definitions, and stop using nullable-access guards in their respective `Message_Handlers`.

## Scope

**In scope:**
- `Podmander.Agent` and child packages (`Connection`, `Message_Handlers`).
- `Podmander.Controller` and child packages (`Message_Handlers`).
- `pod_agent` and `pod_controller` bin entry points if their initialization shape changes.
- `tests/podmander-controller_tests.adb` comment update (no test-logic change required — verified).

**Out of scope:**
- CZMQ binding changes.
- Any other use of access types in the codebase.
- Adding new tests for `Run` / reconnect behaviour beyond what existing coverage provides — the acceptance criterion accepts inspection/valgrind verification.

## Quality bar

- ≤ 8 files touched per unit.
- 0 new abstractions.
- 0 new uses of `Ada.Unchecked_Deallocation`.
- 0 new raw access-type fields for CZMQ resources.

---

## Unit 1: Agent — scope-bound CZMQ resources

**Goal:** Replace `Self.Certificate`/`Self.Socket` access fields on `Agent_Instance` with locals owned by a per-cycle procedure.

**Files:**
- `src/agent/podmander-agent.ads` — drop `Certificate_Access`, `Socket_Access`, `Certificate`, `Socket` fields; remove `Run_Once` from public API.
- `src/agent/podmander-agent.adb` — replace tick-based `Run`-over-`Step` with cycle-based `Run`-over-`Run_Cycle`; apply backoff between cycles.
- `src/agent/podmander-agent-connection.ads` — replace `Step` with `Run_Cycle (Self : in out Agent_Instance)`.
- `src/agent/podmander-agent-connection.adb` — collapse `Handle_Disconnected`/`Handle_Enrolling`/`Handle_Connected` into one procedure with local `Cert : Certificate` and `Sock : Socket`. Update internal helpers (`Send_Register`, `Send_Heartbeat`, `Send_Message`) to take `Sock : in out CZMQ.Sockets.Socket` instead of reading `Self.Socket.all`.
- `src/agent/podmander-agent-message_handlers.ads` — change `Agent_Handler` record so it holds `Sock : access CZMQ.Sockets.Socket` alongside `Agt`. The handler is constructed inside `Run_Cycle`'s connected phase, never with a null/missing socket.
- `src/agent/podmander-agent-message_handlers.adb` — drop the `if H.Agt.Socket /= null` guards in `Send_Deploy_Result` / `Send_Status_Response`; send via `H.Sock.all`.

**Approach:**

```ada
--  podmander-agent-connection.adb (sketch)
procedure Run_Cycle (Self : in out Agent_Instance) is
   Cert : CZMQ.Certificates.Certificate := CZMQ.Certificates.New_Certificate;
   Sock : aliased CZMQ.Sockets.Socket := CZMQ.Sockets.New_Dealer;
begin
   Cert.Apply (Sock);
   Sock.Set_Curve_Serverkey (To_String (Self.Server_Public_Key));
   Sock.Set_Identity (To_String (Self.Config.Agent_Name));
   Sock.Connect (To_String (Self.Config.Controller_Address));
   Sock.Set_Receive_Timeout
     (Integer (Self.Config.Registration_Timeout * 1000.0));

   Self.State := Podmander.Types.Enrolling;
   Send_Register (Self, Sock);

   --  Enrolling phase: receive register response, transition to Connected.
   declare
      Msg : CZMQ.Messages.Message;
      Status : CZMQ.Messages.Receive_Status;
   begin
      CZMQ.Messages.Receive (Sock, Msg, Status);
      if Status = CZMQ.Messages.Timeout then
         Self.State := Podmander.Types.Disconnected;
         return;  --  Cert and Sock finalize on scope exit
      end if;
      --  decode response, populate Self.Node_Id, transition to Connected.
   exception
      when Podmander.Messages.Decode_Error =>
         Self.State := Podmander.Types.Disconnected;
         return;
   end;

   Self.State := Podmander.Types.Connected;
   Self.Backoff := 1.0;
   Sock.Set_Receive_Timeout (Poll_Interval_Ms);

   --  Connected phase: heartbeat-bounded receive loop.
   declare
      Handler : Message_Handlers.Agent_Handler :=
        (Agt => Self'Unchecked_Access, Sock => Sock'Access);
   begin
      while not Podmander.Shutdown.Requested loop
         Send_Heartbeat (Self, Sock);
         --  ... receive-and-dispatch inner loop bounded by next heartbeat ...
         exit when not Self.Running;
      end loop;
   end;
exception
   when CZMQ.CZMQ_Error =>
      Self.State := Podmander.Types.Disconnected;
end Run_Cycle;
```

```ada
--  podmander-agent.adb Run (sketch)
procedure Run (Self : in out Agent_Instance) is
begin
   while Self.Running and then not Podmander.Shutdown.Requested loop
      Connection.Run_Cycle (Self);
      if Self.State = Podmander.Types.Disconnected
        and then Self.Running
        and then not Podmander.Shutdown.Requested
      then
         delay Self.Backoff;
         Self.Backoff := Duration'Min
           (Self.Backoff * 2.0, Self.Config.Max_Backoff);
      end if;
   end loop;
end Run;
```

**Patterns followed:**
- Existing `Self'Unchecked_Access` use in handlers (already-justified in code comments) — preserved, not extended.
- AGENTS.md "controlled types or container ownership" — honored by removing access types entirely.
- Existing `Send_Message` helper shape (encode → send → log) — preserved; only its socket source changes from `Self.Socket.all` to a parameter.

**Test scenarios:**
- [ ] Build: `distrobox enter ada_dev -- alr build` succeeds with no new warnings.
- [ ] Existing tests pass: `distrobox enter ada_dev -- alr test` (covers `host_command_tests`, `host_command-result_mapping_tests`).
- [ ] Manual smoke: start `pod_controller`, start `pod_agent`, observe register + heartbeat exchange in logs.
- [ ] Manual reconnect smoke: while agent is connected, kill `pod_controller`, restart it, observe agent reconnects with backoff and resumes heartbeats. Repeat 5+ cycles.

**Verification:**
- `git grep "Certificate_Access\|Socket_Access" src/agent` returns nothing.
- `git grep "new CZMQ" src/agent` returns nothing.
- `git grep "Self\.Socket\b" src/agent` returns nothing.
- Inspection of `Run_Cycle` confirms `Cert` and `Sock` are declared at procedure scope and not stored elsewhere.

**Planning-time unknowns:**
- *Resolve before planning:* none. The `Self'Unchecked_Access` pattern for handlers is already established in the codebase; passing `Sock'Access` from `Run_Cycle` follows the same justification (handler is stack-local to the inner block).
- *Deferred to implementation:* whether the connected-phase receive loop's existing structure (`while ... loop ... exit when next-heartbeat-due`) needs adjustment for the new scope. Inspect during implementation; if the current shape works as-is, keep it.

---

## Unit 2: Controller — scope-bound CZMQ resources

**Goal:** Replace `Self.Certificate`/`Self.Socket`/`Self.Poller` access fields on `Controller_Instance` with directly-held `Limited_Controlled` fields (Cert/Socket) and a local in `Run` (Poller). Convert two-phase init to a factory function.

**Files:**
- `src/controller/podmander-controller.ads` — drop `Certificate_Access`, `Socket_Access`, `Poller_Access` and the corresponding fields; replace with `Certificate : CZMQ.Certificates.Certificate` and `Socket : CZMQ.Sockets.Socket`. Drop the `Poller` field. Replace `procedure Initialize` with `function Make_Listening_Controller (Config : Controller_Config) return Controller_Instance`. Drop `Run_Once` from public API.
- `src/controller/podmander-controller.adb` — replace `Initialize` body with the factory function using extended return + build-in-place aggregate. Move `Poller` declaration into `Run` as a local. Remove `Run_Once`. `Get_Public_Key` reads `Self.Certificate.Public_Key` directly (no null-check needed; field is always valid in a fully-constructed instance, but tests use a default-initialised instance where the certificate is empty — guard with `Is_Valid`).
- `src/controller/podmander-controller-message_handlers.adb` — replace `H.Ctrl.Socket.all` with `H.Ctrl.Socket`; replace `if H.Ctrl.Socket /= null then` with `if H.Ctrl.Socket.Is_Valid then`. (`Is_Valid` exists on `CZMQ.Sockets.Socket`.)
- `src/bin/pod_controller.adb` — replace `Ctrl : Controller_Instance; Ctrl.Initialize (Config); Ctrl.Run` with `Ctrl : Controller_Instance := Make_Listening_Controller (Config); Ctrl.Run`.
- `tests/podmander-controller_tests.adb` — comment-only edit on line 226 ("when Socket is null" → "when Socket is not yet open"). No test-logic change. `Make_Ctrl` keeps its current shape; its returned `Controller_Instance` has default-initialised (empty) `Certificate` and `Socket`, which is exactly what handler tests need to exercise the guarded send path.

**Approach:**

```ada
--  podmander-controller.ads (sketch)
type Controller_Instance is tagged limited record
   Config      : Controller_Config;
   Certificate : CZMQ.Certificates.Certificate;
   Socket      : CZMQ.Sockets.Socket;
   Agents      : Agent_Maps.Map;
   Running     : Boolean := False;
end record;

function Make_Listening_Controller
  (Config : Controller_Config) return Controller_Instance;

procedure Run (Self : in out Controller_Instance);
procedure Stop (Self : in out Controller_Instance);
function Get_Public_Key (Self : Controller_Instance) return String;
procedure Generate_Join_Token
  (Self  : in out Controller_Instance;
   Token : out Ada.Strings.Unbounded.Unbounded_String);
```

```ada
--  podmander-controller.adb (sketch)
function Make_Listening_Controller
  (Config : Controller_Config) return Controller_Instance is
begin
   return C : Controller_Instance :=
     (Config      => Config,
      Certificate => CZMQ.Certificates.New_Certificate,
      Socket      => CZMQ.Sockets.New_Router,
      Agents      => Agent_Maps.Empty_Map,
      Running     => True)
   do
      C.Certificate.Apply (C.Socket);
      C.Socket.Set_Curve_Server (True);
      C.Socket.Bind (Get_Bind_Address (Config));
      Podmander.Logging.Info
        ("controller", "Listening on " & Get_Bind_Address (Config));
   end return;
end Make_Listening_Controller;

procedure Run (Self : in out Controller_Instance) is
   Poller : CZMQ.Pollers.Poller := CZMQ.Pollers.New_Poller (Self.Socket);
begin
   while Self.Running and then not Podmander.Shutdown.Requested loop
      if Poller.Wait (Poll_Interval_Ms) then
         Handle_Message (Self);
      end if;
      Check_Timeouts (Self);
   end loop;
end Run;
```

**Patterns followed:**
- Extended return / build-in-place aggregate — already used in `tests/podmander-controller_tests.adb:209` (`Make_Ctrl`); pattern is established in this codebase.
- `Is_Valid` guard — analogous to the existing access-null guard, just expressed through the type's own predicate.

**Test scenarios:**
- [ ] Build: `alr build` succeeds.
- [ ] Existing controller tests pass: `Test_Handle_Register_Request_Adds_Agent`, `Test_Handle_Heartbeat_Updates_Last_Seen`, etc. — verifying `Make_Ctrl`'s default-initialised `Controller_Instance` still drives the guarded-send path correctly.
- [ ] Manual smoke: `pod_controller` starts, accepts a `pod_agent` registration, runs heartbeat exchange.
- [ ] Manual shutdown smoke: stop `pod_controller` cleanly (SIGINT); confirm no resource warnings on stderr.

**Verification:**
- `git grep "Certificate_Access\|Socket_Access\|Poller_Access" src/controller` returns nothing.
- `git grep "new CZMQ" src/controller` returns nothing.
- `git grep "\.Socket\.all" src/controller` returns nothing.

**Planning-time unknowns:**
- *Resolve before planning:* The build-in-place aggregate's behaviour with limited components — already validated by the existing `Make_Ctrl` pattern in `tests/podmander-controller_tests.adb:209`. No risk.
- *Deferred to implementation:* `tests/podmander-controller_tests.adb` `Make_Ctrl` may need to also default-initialise `Running` explicitly if the change to `Controller_Instance` defaults breaks anything. Check during implementation.

---

## Dependencies

Unit 1 and Unit 2 are independent. Either can land first. Recommendation: land in two atomic commits within one PR (per the "one issue, one PR, atomic commits" rule).

## Issue body update

The current issue #23 title and acceptance criteria are agent-only. Before opening the PR, update the issue:

- Title: *"Replace agent and controller Socket/Certificate access types with scope-bound resources"*
- Body: extend AC to include `Podmander.Controller` (no raw access types for cert/socket/poller; no new `Unchecked_Deallocation`; build + test pass).
- Add `area/controller` label alongside `area/agent`.

## Verification of acceptance criteria

| AC (extended) | How verified |
|---|---|
| No raw access-type fields in `Agent_Instance` for socket/certificate. | `git grep` (Unit 1 verification). |
| No raw access-type fields in `Controller_Instance` for socket/certificate/poller. | `git grep` (Unit 2 verification). |
| Reconnect cycle (agent) frees the previous CZMQ resources. | Inspection: `Cert` and `Sock` are local to `Run_Cycle`, finalize at every exit path. Optional valgrind run on `pod_agent` over multiple controller restarts. |
| Controller resources released on shutdown. | Inspection: `Certificate`/`Socket` are direct fields on `Controller_Instance`, finalize when the instance leaves scope; `Poller` is a local of `Run`, finalizes on `Run` exit. |
| No new uses of `Ada.Unchecked_Deallocation`. | `git grep "Unchecked_Deallocation"` shows no new occurrences. |
| `alr build` and `alr test` pass. | CI / local. |
