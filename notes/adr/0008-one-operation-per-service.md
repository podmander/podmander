# ADR-0008: One Concurrent Operation per Service

**Status**: Accepted
**Date**: 2026-04-12

## Context

The controller processes deploy, stop, restart, and rollback commands for services. Multiple operators or automated processes (the supervisor loop, scheduled deploys) may issue commands concurrently. Allowing overlapping operations on the same service risks inconsistent state — for example, a rollback starting while a deploy is in progress could leave Quadlet files in a half-updated state.

Key forces:

- Service operations modify Quadlet files, restart systemd units, and update version records. These are multi-step sequences that must complete atomically.
- Different services are independent — there is no reason to serialize operations across unrelated services.
- The supervisor loop issues repair actions that could overlap with operator-initiated deploys.

## Decision

We will allow at most one operation per service at a time. If a deploy is in progress for service X, a second operation targeting service X is rejected. Different services can be deployed concurrently.

## Consequences

### Positive

- No race conditions between overlapping operations on the same service.
- Simple to implement — a per-service lock, no complex transaction coordination.
- Concurrent deploys of different services provide good throughput for cluster-wide operations.

### Negative

- An operator cannot queue a rollback while a deploy is in progress — they must wait for the current operation to complete (or fail).
- Long-running deploys (large images, slow health checks) block other operations on that service.

### Neutral

- The supervisor loop follows the same rules — it cannot repair a service that has an in-progress operation.

## Alternatives Considered

### Global lock (one operation cluster-wide)

- Pros: Simplest to implement, no possibility of cross-service interference.
- Cons: Serializes all operations. Deploying 10 services takes 10× as long as deploying one.
- Why rejected: Unnecessarily slow for the common case of deploying multiple independent services.

### Optimistic concurrency (allow overlap, detect conflicts)

- Pros: Maximum throughput, no blocking.
- Cons: Conflict detection and resolution for multi-step file operations is complex and error-prone. Partial rollback of a half-applied deploy is difficult.
- Why rejected: Complexity disproportionate to the benefit. The per-service lock has negligible impact on throughput since cross-service operations already run in parallel.
