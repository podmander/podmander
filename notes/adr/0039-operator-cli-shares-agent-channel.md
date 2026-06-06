# ADR-0039: Operator CLI Shares the Agent Control-Plane Channel and Enrollment Credential

**Date**: 2026-06-06

## Context

The `podctl` operator CLI needs a way to reach the controller. The control
plane established by [ADR-0009](0009-zeromq-curve-for-control-plane.md) and
[ADR-0036](0036-zeromq-unified-transport.md) is a single ROUTER socket in CURVE
server mode; agents connect as CURVE clients and authenticate with a join token
(`PTKN-<z85-controller-pubkey>-<hex-enrollment-secret>`). There is no
operator-facing endpoint today.

Conceptually an operator is not an agent: it issues commands, hosts no
workloads, and must never be scheduled. That distinctness invites a dedicated
operator socket and/or a distinct operator credential with its own lifecycle.

For the v0.1 MVP ("basic CLI"), the first and only operator capability is
submitting a service TOML for registration (`Submit_Stack`), which retires the
`--test-config` proof-of-concept scaffold. The forces shaping the decision:

- ADR-0036 mandates ZeroMQ as the *sole* transport between the parts of the
  system — a second protocol would contradict it.
- The system has no production users, so no migration or compatibility
  constraints apply.
- "Basic" argues for the smallest new surface that works; a full operator
  authorization model is more than the milestone needs.
- The decision should not paint us into a corner: an operator command *family*
  (status, scale, rollback, secrets) is coming.

## Decision

We will have `podctl` reuse the agents' control-plane channel and enrollment
credential rather than introduce an operator-specific socket or credential.

- `podctl` connects as a CURVE client to the **existing agent ROUTER socket**.
  No separate operator endpoint is bound.
- `podctl` is configured with a **join token** — the same kind agents use. It
  parses the token to recover the controller's public key (for the CURVE
  handshake) and the enrollment secret. No controller filesystem artifact (e.g.
  `controller.crt`) is read.
- The enrollment secret travels in the operator message
  (`Submit_Stack.Enrollment_Secret`) and is validated by the **same**
  `Enrollment.Secret_Matches` check applied to agent registration.
- `podctl` is **not** an agent: it does not send a `Registration_Request`, never
  appears in the `agents` table, and is never scheduled. Operator messages are
  distinguished by their message `kind`; the controller replies to the sender's
  ROUTER routing identity rather than to a registered agent entry.
- Authorization for MVP is **possession of the join token**. A distinct operator
  credential/role and a dedicated operator endpoint are deferred until a
  concrete need arises.

## Consequences

### Positive

- No new transport or key-management surface: the operator path reuses the
  ADR-0036 channel and ADR-0009 enrollment wholesale.
- `podctl`'s configuration is a single self-contained token string, exactly like
  an agent's. It carries no dependency on a controller-side file.
- Operator requests are *authenticated* (the secret is checked), not merely
  reachable — strictly stronger than a public-key-only trust model.
- The existing `kind`-based message dispatch absorbs operator messages cheaply,
  and the `<Verb>_<Object>` / `<Verb>_<Object>_Result` naming convention scales
  to the anticipated operator command family.

### Negative

- Operators and agents share one credential. Revoking operator access means
  rotating the join token, which also forces agent re-enrollment — there is no
  independent operator revocation.
- Operator and agent traffic share one socket and interface; they cannot be
  firewalled, rate-limited, or bound separately.
- The join token's enrollment secret is used beyond its original enrollment
  purpose, mildly overloading its meaning.

### Neutral

- The controller distinguishes operator from agent messages by `kind` and must
  reply to a routing identity that has no agent record.
- Moving to a separate operator socket and/or credential later is a localized
  change (an additional bind plus client configuration), not a protocol-wide
  migration.

## Alternatives Considered

### Separate operator socket (second bind or Unix socket)

- Pros: clean separation of operator and agent traffic; independent binding,
  firewalling, and rate-limiting.
- Cons: doubles the socket and authentication surface; a second CURVE
  configuration to manage.
- Why rejected: more than "basic" requires. Revisit if traffic separation
  becomes a real requirement.

### Distinct operator credential/role

- Pros: independent operator revocation; supports least privilege.
- Cons: needs a credential issuance and storage mechanism the MVP otherwise
  does not.
- Why rejected: a natural follow-up, but out of scope for v0.1.

### Local-only `podctl` writing SQLite directly

- Pros: no wire protocol at all.
- Cons: violates [ADR-0037](0037-database-only-state-access.md) (the controller
  is the sole DB writer); only works on the controller host.
- Why rejected: incompatible with the state-access model.

### Read the controller public key from `controller.crt` on disk

- Pros: no token handling in `podctl`.
- Cons: couples `podctl` to a controller filesystem artifact, and provides no
  authorization — anyone able to reach the socket could submit.
- Why rejected: the self-contained token gives both the key and real
  authorization with no file coupling.

## References

- [ADR-0009](0009-zeromq-curve-for-control-plane.md) — Join token and CURVE
  control plane
- [ADR-0036](0036-zeromq-unified-transport.md) — ZeroMQ as sole transport
- [ADR-0037](0037-database-only-state-access.md) — Controller is the sole state
  writer
- `DOMAIN.md` — CLI (`podctl`), Stack Submission, `Submit_Stack`,
  `Submit_Stack_Result`
