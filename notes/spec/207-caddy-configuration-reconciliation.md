# Caddy Configuration Reconciliation

Implementation contract for Forgejo issue #207. This specification implements
ADR-0045 and excludes drift repair, ingress failover, external probes, and
operator rollback.

## Scope and invariants

- Caddy is one Infrastructure Component on the persisted Ingress Node.
- The Scheduler persists the Ingress Node while scheduling the first
  Ingress-bearing Service Version in the same database transaction as that
  Service's initial Catalog assignment. The lock survives empty route sets,
  Agent loss, and Node deletion until a future explicit replacement workflow
  changes it.
- Caddy routes come only from Service Catalog Entries on that Node whose
  `current_version` deployed successfully. `target_version` never creates a
  route. A failed Service update leaves the current Version's route in place.
- This MVP uses the existing single-node First Available placement. A future
  multi-node scheduler must co-locate Ingress-bearing Services with the locked
  Ingress Node or define an explicit cross-node migration contract; that work is
  outside #207.
- A Caddy apply failure does not roll back Service deployment or placement.
- Exactly one Caddy Apply Attempt may be non-terminal (`Prepared` or `Sent`) at
  a time.

## Persistent model

### Caddy Component

One row per persisted Ingress Node. It stores the Ingress Node identity, the
latest desired Version, and the last confirmed active Version. Availability and
delivery safety are separate states: availability is `Available` or
`Unavailable`; delivery safety is `Ready` or `Frozen`.

Availability becomes `Unavailable` when no registered Agent serves the locked
Node. `Frozen` means an Attempt is `Unknown` or `Rollback_Failed`, or that a
predecessor mismatch exposed unexpected active bytes. A returning Agent changes
availability only; it never clears `Frozen`.

Deleting a Node referenced by a Caddy Component tombstones the Node record. The
Component retains its identity and becomes unavailable until a future explicit
failover or operator workflow replaces the Ingress Node lock. Ordinary Agent
registration cannot revive a tombstoned Node.

### Caddy Configuration Version

An immutable Infra Version scoped to one Caddy Component. It stores a monotonic
Version number, canonical Caddyfile bytes, SHA-256 lowercase-hex content hash,
source (`reconcile`), and lineage to the prior successful Version. It has no
mutable apply outcome.

The controller creates a Version when canonical bytes differ from the latest
Version, regardless of that Version's previous Attempt outcome. A changed
Version after a normal failure is a new desired state, not a retry.

### Caddy Apply Attempt

A durable delivery record with a database-generated monotonic Attempt ID.
It stores the Configuration Version, expected predecessor hash, send timestamp,
deadline, terminal outcome, active hash after the attempt when known, failure
stage, and diagnostic.

Attempt states are `Prepared`, `Sent`, `Applied`, `Failed`, `Unknown`, and
`Rollback_Failed`. `Prepared` and `Sent` are non-terminal. `Unknown` is
controller-generated; the Agent never emits it. `Not_Delivered` is not an
Attempt state: it is the Component's unavailable availability state before a
command exists.

| From | To | Controller transaction |
| ---- | -- | ---------------------- |
| `Prepared` | `Sent` | Send succeeds; persist the 30-second deadline. |
| `Prepared` | `Failed` | Initial send fails; record controller-only `Delivery` stage. |
| `Sent` | `Applied` | Matching result confirms candidate hash; set it as known active and keep safety `Ready`. |
| `Sent` | `Failed` | Matching result reports the expected predecessor hash; retain that Version as known active. |
| `Sent` | `Failed` | Matching result reports a trustworthy but unexpected active hash, including `Stale_Predecessor`; persist the observed hash and set safety `Frozen`. |
| `Sent` | `Rollback_Failed` | Matching result lacks a trustworthy active hash; set safety `Frozen`. |
| `Sent` | `Unknown` | Deadline expires; set safety `Frozen`. |
| `Unknown` | `Applied` | Matching late result confirms candidate hash; set it as known active and clear `Frozen`. |
| `Unknown` | `Failed` | Matching late result confirms the expected predecessor hash; retain it as known active and clear `Frozen`. |
| `Unknown` | `Failed` | Matching late result reports a trustworthy but unexpected active hash; persist the observed hash and keep safety `Frozen`. |
| `Unknown` | `Rollback_Failed` | Keep safety `Frozen`. |

Any result with an absent or unexpected active hash, including
`Stale_Predecessor`, sets safety `Frozen` rather than following the ordinary
`Failed` transition. The exception is a first-install `Failed` result with no
expected predecessor and no active hash: it confirms a known empty Caddy state,
leaves `known_active_version` null, and keeps safety `Ready`.

## Route rendering

The Supervisor reconciles whenever the eligible route set changes: a current
Service Version deploys, is removed or lost, or moves onto or off the Ingress
Node. Component initialization after the first Ingress-bearing Service is
scheduled also reconciles the canonical no-route configuration.

Eligible routes are sorted by normalized hostname in lexical order. Output uses
LF line endings, no global block, and concatenates site blocks exactly as:

```caddyfile
example.com {
    reverse_proxy 127.0.0.1:8080
}
```

The loopback port is the Ingress Named Port's published host port. With no
eligible routes, the canonical Caddyfile is:

```caddyfile
http:// {
}
```

This valid, no-route Caddyfile prevents removed routes from remaining active.

## Reconciliation and delivery

1. Render the eligible route snapshot and create a new desired Version only if
   its bytes differ from the latest Version.
2. If the locked Node has no registered Agent, set availability to `Unavailable`;
   retain the desired Version and create no Attempt.
3. When that same Node registers, set availability to `Available` and deliver the
   latest desired Version if safety is `Ready` and it has no Attempt. This is
   first delivery, not a retry.
4. If an Attempt is `Prepared` or `Sent`, persist later changed desired Versions
   but do not create or send another Attempt until it reaches a terminal outcome.
   Recovery resolves or first-sends the existing `Prepared` Attempt first.
5. Persist a `Prepared` Attempt before any ZeroMQ send. If the last confirmed
   active Version is available, carry its hash as `expected_previous_hash`. For
   the first apply, the predecessor is absent and the Agent requires no managed
   committed file.
6. After a successful send, move the Attempt to `Sent` and persist a deadline 30
   seconds later. An initial send failure becomes `Failed` at `Delivery`.
   Controller restart resends a recovered `Prepared` Attempt with the same
   Attempt ID. If that recovered resend fails, it becomes `Unknown` and freezes
   delivery because the earlier send may have reached the Agent. Expired `Sent`
   Attempts also become `Unknown`.
7. A `Failed` Attempt leaves the prior confirmed Version active. The same desired
   bytes do not create or deliver another Version. A later different Version may
   be delivered if the predecessor remains known.
8. An `Unknown` or `Rollback_Failed` Attempt sets safety to `Frozen`. A result
   with `Stale_Predecessor` also freezes delivery when its active hash differs
   from the last confirmed active hash. The controller may persist later desired
   Versions but sends none until remediation resolves the component state.

## Protocol contract

`Caddy_Config_Command` and `Caddy_Config_Result` are controller-to-Agent and
Agent-to-controller messages respectively. They use the existing ZeroMQ/CURVE
transport and are distinct from Service deployment messages.

### Caddy_Config_Command

Required fields:

- `kind`: `caddy_config_command`;
- `attempt_id`: monotonic Apply Attempt ID;
- `configuration_version`: monotonic Caddy Configuration Version number;
- `content`: exact UTF-8 canonical Caddyfile bytes;
- `candidate_hash`: SHA-256 lowercase-hex hash of `content`;
- `expected_previous_hash`: the last confirmed active hash, or absent only for
  the first apply.

### Caddy_Config_Result

Required fields:

- `kind`: `caddy_config_result`;
- `attempt_id`, `configuration_version`, and `candidate_hash` copied from the
  command;
- `outcome`: `Applied`, `Failed`, or `Rollback_Failed`;
- `active_hash`: the hash active after the attempt, absent when rollback failed
  or a first-install failure leaves no active Caddy configuration;
- `failure_stage`: absent on success, otherwise `Hash_Mismatch`,
  `Stale_Predecessor`, `Validation`, `Replacement`, `Reload`, `Health_Check`,
  or `Rollback`; `Delivery` is controller-only and never appears in an Agent
  Result;
- `diagnostic`: at most 4096 UTF-8 bytes of human-readable failure detail,
  truncated only at a valid UTF-8 boundary and absent on success.

The controller accepts a Result only when Attempt ID, Configuration Version, and
candidate hash match persisted data and the authenticated sending Agent resolves
to the Attempt's locked Ingress Node. Duplicate terminal Results are no-ops. A
matching late Result may resolve only its `Unknown` Attempt and never replaces a
newer Component active pointer.

## Agent apply transaction

The Agent manages `/etc/podmander/caddy/Caddyfile`, a retained prior committed
Caddyfile, and a durable apply journal. Journal and backup writes are fsynced
before replacement. A one-shot recovery step runs before
`podmander-caddy.service` starts and before the Agent handles another command.
An incomplete journal restores and reloads the prior committed Caddyfile. If no
prior committed file exists, recovery removes the candidate and stops Caddy.

The Agent also retains the latest terminal Apply Attempt receipt: Attempt ID,
Configuration Version, candidate hash, and exact Result. It fsyncs that receipt
before sending the Result. A duplicate matching command replays the receipt
without another validation, replacement, reload, or health check.

For a command, the Agent:

1. hashes received bytes and rejects a candidate-hash mismatch;
2. returns idempotent `Applied` if the committed file already has the candidate
   hash;
3. otherwise compares the committed file to `expected_previous_hash` and rejects
   a mismatch as `Stale_Predecessor` without mutation;
4. validates the candidate in a network-disabled ephemeral container using the
   same pinned Caddy image as the Quadlet;
5. fsyncs the candidate, journal, and their parent directories; every later
   rename or removal is followed by an fsync of its parent directory;
6. atomically replaces the managed Caddyfile, then starts
   `podmander-caddy.service` for the first apply or reloads it for later applies;
7. confirms that the systemd service remains active, fsyncs the committed journal
   state, and returns `Applied` with the candidate hash;
8. on replacement, start, reload, or health-check failure, restores and reloads
   prior committed file; successful restoration returns `Failed` with the prior
   active hash, while failed restoration returns `Rollback_Failed` without an
   active hash;
9. for a first-install failure with no prior committed file, removes the
   candidate, stops `podmander-caddy.service`, and returns `Failed` without an
   active hash only after both cleanup actions succeed; cleanup failure returns
   `Rollback_Failed` and leaves delivery frozen.

## Deferred behavior

The following remain outside #207: external serving probes, heartbeat hash
reporting, drift detection, automatic repair, operator rollback, retry policy
beyond first delivery after Node return, multi-ingress operation, and automatic
Ingress Node failover.
