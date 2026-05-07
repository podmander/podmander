# ADR-0005: Three-State Model (Desired, Expected, Actual)

**Status**: Accepted
**Date**: 2026-04-12

## Context

An orchestrator must track what the operator wants, what the system has been told to do, and what is actually running. Conflating these creates ambiguity: is a service "deployed" because the operator declared it, because the scheduler assigned it to a node, or because the agent confirmed it is running?

Key forces:

- The scheduler makes placement decisions that may differ from the operator's declaration (e.g., choosing which specific nodes get replicas).
- Agents report reality, which may diverge from both the operator's intent and the scheduler's plan (drift, crashes, manual changes).
- The supervisor loop needs to compare two concrete states (expected vs actual) to detect and repair drift.
- Debugging requires visibility into where a discrepancy originated — was the declaration wrong, the scheduling wrong, or the execution wrong?

## Decision

We will maintain three distinct state levels in the controller's SQLite database:

1. **Desired state** — what the operator declared in TOML configuration. The intent.
2. **Expected state** — what the scheduler decided should be deployed where. The plan.
3. **Actual state** — what agents report is running on each node. The reality.

The supervisor loop compares expected against actual. The scheduler produces expected from desired. These are separate concerns with separate update paths.

## Consequences

### Positive

- Clear separation between intent, plan, and reality. Each can be inspected independently.
- The supervisor loop has an unambiguous reference point (expected state) for drift detection — it does not need to re-derive scheduling decisions.
- Debugging is straightforward: compare desired→expected to find scheduling issues, compare expected→actual to find execution issues.
- Supports future scenarios like "drain node" (update expected state without changing desired state).

### Negative

- Three state tables to maintain, migrate, and keep consistent.
- State transitions must be carefully ordered to avoid inconsistencies (e.g., expected state must not reference a node that desired state does not include).

### Neutral

- The `podctl status` command can show divergences at each level, giving operators a clear picture of where issues lie.

## Alternatives Considered

### Two-state model (desired + actual)

- Pros: Simpler — fewer tables, fewer state transitions.
- Cons: The scheduler's placement decisions are implicit. Drift detection requires re-running scheduling logic on every comparison. "What should be running on node X?" has no precomputed answer.
- Why rejected: Re-deriving scheduling on every supervisor loop iteration is wasteful and fragile. The expected state layer makes drift detection a simple comparison.

### Single-state model (actual only, with declarations as input)

- Pros: Minimal storage, no state synchronization.
- Cons: No persistent record of what should be running. Cannot detect drift (nothing to compare against). Cannot survive controller restart without re-reading all TOML files.
- Why rejected: Fundamentally incompatible with self-healing and drift detection.
