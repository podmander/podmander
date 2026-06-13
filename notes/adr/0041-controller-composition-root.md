# ADR-0041: Controller as a Composition Root, with Reconciliation, Liveness, Transport, and Enrollment as Collaborators

**Date**: 2026-06-13

## Context

`Controller_Instance` is on a god-object trajectory. Today it legitimately owns
the long-lived resources — `DB`, `Socket`, `Certificate`, `Running` — but its
body also *performs* four unrelated jobs inline:

- **Reconciliation** — `Reconcile_State`, `Schedule_Unscheduled`,
  `Deploy_Pending`, `Try_Deploy_Entry`, `To_Service_Definition`
  (`src/controller/podmander-controller.adb:245-388`).
- **Agent liveness** — `Check_Timeouts`, the Registered->Unresponsive->Lost
  state machine (`adb:194-229`).
- **Transport** — `Handle_Message` plus a raw `Msg.Send (Self.Socket)` buried in
  `Try_Deploy_Entry` (`adb:166-192`, `adb:319-323`); the message handlers also
  send through `Ctrl.Socket`.
- **Credential bootstrap** — CURVE certificate and registration-secret
  load/generate in the constructor, plus `Get_Public_Key` /
  `Generate_Join_Token` (`adb:104-155`, `adb:395-412`).

Two forces make this non-obvious rather than a routine tidy-up:

- **The domain already names a Supervisor Loop** as a first-class concept
  (`DOMAIN.md`; [ADR-0006](0006-continuous-supervisor-loop.md): "The Supervisor
  reads Service Catalog Entries and produces Deploy_Commands"), yet there is no
  Supervisor object — the controller *is* the supervisor. The code lags the
  language.
- **The controller's scope grows extensively from here.** Drift detection and
  the auto-repair-vs-alert policy ([ADR-0006](0006-continuous-supervisor-loop.md)),
  infrastructure-component reconciliation with its own versioning
  ([ADR-0024](0024-infrastructure-component-versioning.md)), agent-mediated
  secret delivery ([ADR-0022](0022-agent-mediated-secret-delivery.md)),
  service-level status reporting, and richer placement strategies
  ([ADR-0040](0040-node-as-first-class-domain-object.md)) each default to landing
  as *more procedures in `podmander-controller.adb`*.

Constraints: no production users, so we can refactor freely; the handler tests
already deliberately drive logic without a live socket
(`src/controller/podmander-controller.ads:123-128`), so transport coupling is
already felt as friction.

## Decision

We will treat `Controller_Instance` as a **composition root / process host**: it
owns the long-lived resources and wires collaborators together, but delegates
domain work to four named collaborators, each mapped to existing domain language
and each the natural home for a category of future growth.

1. **Supervisor** (`Podmander.Controller.Supervisor`) — owns one reconciliation
   tick over the Service Catalog: schedule unscheduled entries, deploy pending
   ones, resolve Node->Agent, render the Quadlet, emit the `Deployment_Command`.
   This realizes the Supervisor Loop named in `DOMAIN.md` and
   [ADR-0006](0006-continuous-supervisor-loop.md). It is where drift detection,
   the auto-repair-vs-alert policy, expected-state comparison, and infra-component
   reconciliation will live. The controller's `Run` shrinks to: poll -> dispatch
   message -> `Supervisor.Tick`. The crash-recovery reset of
   `In_Progress`->`Pending` entries becomes the Supervisor's startup concern,
   consistent with ADR-0006's "startup, steady state, and recovery are the same
   loop" — no separate recovery object.

2. **Liveness Monitor** (`Podmander.Controller.Agent.Liveness`) — owns the
   heartbeat-driven agent state machine (Registered->Unresponsive->Lost), today's
   `Check_Timeouts`. The startup reset of agents to `Unresponsive` moves here. It
   grows when agents begin reporting service-level status
   (RUNNING/STOPPED/DEPLOY_FAILED).

3. **Control Channel** (`Podmander.Controller.Control_Channel`) — wraps the
   ZeroMQ ROUTER socket behind two operations: receive-and-decode the next
   message, and send to a connection identity. It removes direct `Self.Socket`
   access from `Handle_Message`, `Try_Deploy_Entry`, and the message handlers,
   and makes "drive handlers without a live socket" the designed seam rather than
   a workaround. It must not leak CZMQ types across its boundary.

4. **Enrollment Authority** (`Podmander.Controller.Enrollment_Authority`) — owns
   the controller's cryptographic identity and enrollment credentials:
   CURVE-certificate load/generate, registration-secret load/generate, join-token
   issuance (`Get_Public_Key`, `Generate_Join_Token`), and the shared
   secret-authorization check used by both agent enrollment and Stack Submission.
   It is the home for secret rotation.

The controller retains config accessors, `Make_Listening_Controller` (now mostly
wiring the collaborators), `Run` (the poll loop), and `Stop`. Resource
*ownership* stays at the composition root; collaborators receive the
`DB`/`Socket`/`Certificate` they need — only behavior moves out.

This ADR captures the decomposition and the collaborator names. The code changes
are tracked in separate issues, one per collaborator, per our one-issue-one-PR
cadence.

## Consequences

### Positive

- The god-object trajectory is broken: each future feature category (drift,
  infra, secrets, status) has a named home instead of accreting on
  `Controller_Instance`.
- The Supervisor Loop becomes real in code, not just in prose — the language and
  the model converge.
- Transport is decoupled from domain logic, making the existing "test handlers
  without a live socket" pattern a designed seam.
- Enrollment and credentials get a single owner; secret rotation has somewhere to
  land.
- Each collaborator is independently testable.

### Negative

- Four extractions touching the controller's core; they need sequencing to avoid
  re-churning the same lines. Each is its own PR.
- More packages and indirection for a codebase one person can still hold in their
  head today.
- The Control Channel earns its keep only if it fully hides CZMQ; a leaky wrapper
  adds a layer without buying the decoupling.

### Neutral

- `Controller_Instance` keeps owning `DB`, `Socket`, and `Certificate`;
  collaborators borrow them. Ownership does not move, only behavior.
- **Fleet** and a rich in-memory **Service Catalog** aggregate are deliberately
  *not* introduced (YAGNI). The controller is the fleet's runtime embodiment, and
  the catalog repository plus the Supervisor are sufficient; revisit Fleet only
  if multi-fleet or fleet-level config arrives.

## Alternatives Considered

### Keep the logic in the controller, extract private child procedures only

- Pros: minimal churn; no new public types; the body is already partly split this
  way.
- Cons: doesn't break the trajectory — the body keeps growing; no testable seams
  emerge; the Supervisor stays nameless.
- Why rejected: cosmetic. It treats the symptom (a long body) rather than the
  cause (mixed responsibilities).

### One `Controller_Services` collaborator holding all the moved logic

- Pros: a single extraction.
- Cons: relocates the god object next door without separating the
  responsibilities.
- Why rejected: it fails the same SRP test the controller is failing now.

### Introduce `Fleet` as the top-level object now

- Pros: matches the glossary's administrative whole.
- Cons: a pass-through today; speculative absent multi-fleet.
- Why rejected: YAGNI. Revisit when fleet-level concerns are real.

### Make crash recovery its own object

- Pros: names the restart path explicitly.
- Cons: [ADR-0006](0006-continuous-supervisor-loop.md) explicitly rejects a
  separate recovery mode.
- Why rejected: contradicts a standing decision; the resets fold into
  Supervisor/Liveness startup instead.

## References

- [ADR-0006](0006-continuous-supervisor-loop.md) — Continuous supervisor loop;
  the Supervisor and "startup = steady state = recovery"
- [ADR-0040](0040-node-as-first-class-domain-object.md) — Node->Agent resolution
  in the deploy path (Supervisor) and the routing identity (Control Channel)
- [ADR-0037](0037-database-only-state-access.md) — Crash-recovery resets at
  startup
- [ADR-0024](0024-infrastructure-component-versioning.md) — Future Supervisor
  scope (infra reconciliation)
- [ADR-0022](0022-agent-mediated-secret-delivery.md) — Future Enrollment
  Authority / secret scope
- [ADR-0009](0009-zeromq-curve-for-control-plane.md) — CURVE certificate (Control
  Channel, Enrollment Authority)
- [ADR-0039](0039-operator-cli-shares-agent-channel.md) — The Control Channel
  carries both agent and CLI traffic
- `DOMAIN.md` — Supervisor Loop, Controller, Scheduler, Registrar, Enrollment
- Issue #160 — Controller decomposition (umbrella)
