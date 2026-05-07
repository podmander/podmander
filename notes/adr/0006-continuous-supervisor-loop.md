# ADR-0006: Continuous Supervisor Loop for Reconciliation

**Status**: Accepted
**Date**: 2026-04-12

## Context

The controller must reconcile expected state with actual state reported by agents. This reconciliation needs to handle startup, steady-state operation, and failure recovery. A key design question is whether these should be separate code paths or a unified mechanism.

Key forces:

- On startup, the controller may find services in unexpected states (crashed during downtime, manually modified).
- During steady state, drift can occur at any time (service crashes, config file edits, node reboots).
- After failures, the system needs to converge back to expected state without operator intervention.
- Separate recovery modes create edge cases at mode boundaries and increase code complexity.

## Decision

We will use a single continuous reconciliation loop for all phases of operation. There is no separate "startup mode," "recovery mode," or "repair mode." The same loop handles initial convergence, steady-state monitoring, and failure repair.

The loop runs on a configurable interval:

1. Collect actual state from agent heartbeats.
2. Compare expected state against actual state.
3. On match — do nothing.
4. On divergence — check policy (auto-repair or alert-only) and act accordingly.

A configurable grace period prevents false alerts during cluster boot.

## Consequences

### Positive

- One code path for all reconciliation — no edge cases at mode boundaries.
- Self-healing is automatic: any divergence triggers the same repair logic regardless of cause.
- Startup convergence is natural: the controller simply begins comparing and repairing.
- Easier to reason about and test — the loop is the same whether the cluster just booted or has been running for months.

### Negative

- The grace period must be tuned correctly — too short causes false repairs during startup, too long delays genuine drift detection.
- Auto-repair can cause thrashing if a service repeatedly fails. Rate limiting on repair actions is a future concern.

### Neutral

- The loop compares expected vs actual state (see [ADR-0005](0005-three-state-model.md)), so it does not need to re-derive scheduling decisions.

## Alternatives Considered

### Separate startup/recovery/steady-state modes

- Pros: Each mode can be optimized for its specific scenario (e.g., startup could batch-deploy everything at once).
- Cons: Mode transitions create edge cases. What if a failure occurs during startup? The system needs to handle "recovery during startup" — effectively a third mode. Complexity compounds.
- Why rejected: The unified loop handles all scenarios naturally. Batch optimization during startup can be achieved within the loop via queuing, without separate modes.

### Event-driven reconciliation (react to changes only)

- Pros: More efficient — no polling, no wasted comparisons when nothing changed.
- Cons: Missed events (network partition, agent restart) leave the system in an inconsistent state with no mechanism to self-correct. Requires a separate periodic "full sync" as a fallback — which is effectively the supervisor loop anyway.
- Why rejected: Periodic reconciliation is the safety net that makes the system reliable. Events can be layered on top as an optimization, but the loop is the foundation.
