# ADR-0042: The Control Channel owns its socket

**Date**: 2026-06-14

## Context

[ADR-0041](0041-controller-composition-root.md) decomposed the controller into
four collaborators and chose a single ownership model for all of them: the
controller is the composition root, it owns the long-lived resources (`DB`,
`Socket`, `Certificate`), and collaborators *borrow* what they need. The Control
Channel (#163) was built to that model -- it holds an `access CZMQ.Sockets.Socket`
pointing at the controller's socket.

That model is right for the `DB`: the database is genuinely shared, with the
Supervisor, the Liveness Monitor, and the message handlers all legitimately
reading and writing it. One owner, many borrowers is honest.

The **socket is not shared**. The Control Channel exists specifically to be the
single gateway to ZeroMQ; it is the socket's only legitimate user. Treating the
socket like the DB -- a borrowed shared resource -- is a category error, and it
produced a split-responsibility result that the borrow design cannot fully fix:

- Transport setup stays in the controller: `Make_Listening_Controller` calls
  `Open_Router`, `Certificate.Apply`, `Set_Curve_Server`, and `Bind`.
- `Run` still polls the raw socket through `CZMQ.Pollers`.
- The borrow requires `Self.Socket'Unchecked_Access`, an unchecked lifetime
  assumption; and because `Podmander.Controller.Control_Channel` is a *child* of
  `Podmander.Controller`, the parent cannot hold a field of the child's type
  (a parent unit cannot `with` its own child), so the channel must be
  reconstructed transiently at every send site.

The net effect is that CZMQ is confined to *the channel plus the controller's
constructor and poll loop* -- two objects sharing transport responsibility. This
is precisely the "leaky wrapper adds a layer without buying the decoupling"
failure mode that ADR-0041 named in its own Negative consequences. ADR-0041's
borrow choice was a reasonable way to keep each extraction PR small and
sequenced, but it under-examined the socket's ownership by lumping it in with the
DB; as an end state it leaves an SRP conflict.

Constraints and forces: no production users, so we can refactor freely; the next
collaborator (the Enrollment Authority) will own the CURVE certificate, and the
certificate is applied to the socket at bind time -- so socket ownership and
certificate ownership are coupled questions best decided together.

## Decision

We will make the **Control Channel own its socket** rather than borrow it.

1. **Re-parent the package out of the controller hierarchy** to a sibling unit
   (e.g. `Podmander.Control_Channel`, or under a `Podmander.Transport` parent).
   This dissolves the parent/child circular dependency, which is what forced the
   transient construction and `Unchecked_Access` in the first place.

2. **The Channel owns the socket by value** -- a limited, self-finalizing type
   that holds a `CZMQ.Sockets.Socket` directly. It gains lifecycle operations
   (`Listen`, `Close`); `Open_Router`, `Set_Curve_Server`, the CURVE
   certificate application, and `Bind` move out of the controller and into the
   Channel.

3. **Fold the poll wait into `Receive`.** `Receive` already reports `No_Message`
   on a receive timeout; with `Set_Receive_Timeout` providing the loop cadence,
   `Run`'s `CZMQ.Pollers.Poller` disappears and the controller's `Run` loop calls
   `Self.Channel.Receive` directly. After this, the controller names no CZMQ type
   at all.

4. **The controller holds the Channel as a field** (now legal, since the Channel
   is no longer a child). `Make_Listening_Controller` constructs it, passing the
   bind address and the certificate to apply. Message handlers send through
   `H.Ctrl.Channel.Send (...)` -- a plain field access. The borrow, and
   `'Unchecked_Access`, cease to exist.

This revises ADR-0041 for the socket specifically. The DB and Certificate stay
owned by the controller (the DB is genuinely shared; the Certificate's ownership
is the Enrollment Authority's concern, tracked separately), and the other three
collaborators are unaffected.

The `Send`/`Receive` operations, their CZMQ-free signatures, and their tests --
delivered in #163 -- carry forward unchanged. Only construction, ownership, and
the poll loop move. Implementation is tracked in #170 and should be sequenced
with the Enrollment Authority extraction so socket and certificate ownership are
settled together.

## Consequences

### Positive

- Transport responsibility lives in exactly one object. CZMQ no longer leaks
  into the controller's constructor or poll loop; the wrapper stops being leaky.
- The borrow and its `Unchecked_Access` lifetime assumption are eliminated
  outright -- the socket cannot dangle because its lifetime *is* the Channel's.
- Re-parenting removes the circular dependency, so the Channel becomes an
  ordinary field and handlers reach it by field access -- no transient
  reconstruction, no `Wrap` indirection.
- `Run` shrinks to poll-via-Receive -> dispatch -> Tick and names no CZMQ type.

### Negative

- Reverses two ADR-0041 decisions (resource ownership stays at the controller;
  the Control Channel is a controller child). Documented churn rather than silent
  drift, but still churn.
- The Channel becomes a limited type (owning a controlled socket), so it cannot
  be copied -- callers hold or pass it by reference.
- Touches `Make_Listening_Controller`, `Run`, the handlers' send path, and every
  `with` clause naming the old child package -- a wider radius than the #163
  borrow refactor.

### Neutral

- The "drive handlers without a live socket" test seam is preserved: a Channel
  whose socket has not been opened still reports `Is_Valid = False`, so `Send`
  continues to no-op.
- The controller keeps owning the `DB` and the `Certificate`; only the socket's
  ownership moves.

## Alternatives Considered

### Keep the borrow, make it compiler-checked with an access discriminant

- Pros: keeps the socket in the controller; the compiler enforces that the
  Channel cannot outlive the socket, removing the `Unchecked_Access` trust.
- Cons: the Channel becomes limited anyway; construction gets more verbose;
  borrowing through the handler's `access Controller_Instance` is awkward; and it
  leaves the underlying split responsibility (transport setup and polling still
  in the controller) untouched.
- Why rejected: it checks the symptom (the unsafe borrow) without fixing the
  cause (misplaced ownership).

### Reference-counted shared ownership of the socket

- Pros: no holder can dangle; the socket lives as long as any reference does.
- Cons: heap-allocates a socket that is currently a clean inline component;
  requires a hand-rolled controlled refcount type (Ada has no built-in `Rc`);
  shifts a single-owner, single-threaded resource to shared ownership.
- Why rejected: heavy machinery for a problem we do not have.

### Leave it as the ADR-0041 borrow

- Pros: no further change; #163 already shipped it.
- Cons: preserves the leaky wrapper and the split transport responsibility.
- Why rejected: the borrow was a fine incremental step but a poor end state;
  with the Enrollment Authority extraction about to touch the same ownership
  question, now is the moment to correct it.

## References

- [ADR-0041](0041-controller-composition-root.md) -- Controller as composition
  root; this ADR revises its socket-ownership decision and the Control Channel's
  placement as a controller child
- [ADR-0009](0009-zeromq-curve-for-control-plane.md) -- CURVE certificate applied
  to the socket (the socket/certificate ownership coupling)
- [ADR-0022](0022-agent-mediated-secret-delivery.md) -- Enrollment Authority /
  credential scope, to be sequenced with this change
- Issue #170 -- implementation
- Issue #163 / PR #168 -- the borrow-based Control Channel this builds on
