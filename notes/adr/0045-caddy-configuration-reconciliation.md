# ADR-0045: Caddy Configuration Reconciliation

**Date**: 2026-07-25
**Status**: Proposed

## Context

Ingress routes require one complete Caddy configuration for the Node selected to
host ingress. ADR-0024 establishes node-scoped Infrastructure Versions, but it
does not define Caddy reconciliation, safe application, or uncertain outcomes.

Caddy changes are caused by Service deployment state but must not become Service
Catalog deployments. A Caddy failure must not undo a successful Service
deployment, and a delayed command must not overwrite newer or unknown state.

## Decision

We will model Caddy as a singleton Infrastructure Component on a persisted
Ingress Node. The Scheduler persists that Node when it schedules the first
Ingress-bearing Service Version. The lock survives zero routes and Node loss;
automatic re-election is deferred.

The Component owns immutable Caddy Configuration Versions and mutable Caddy
Apply Attempts. A Version contains only content, hash, number, source, and
lineage. An Attempt contains delivery correlation and outcome. The Component
separately records desired and last-confirmed-active Versions.

For Caddy, this ADR refines ADR-0024: Apply Attempt outcomes are separate from
immutable Infrastructure Versions, and `reconcile` is a Caddy Version source in
addition to its existing `deploy`, `rollback`, and `repair` examples. Heartbeat
hash reporting and automatic repair remain deferred.

The Supervisor derives deterministic Caddyfiles only from successfully deployed
`current_version` entries on the Ingress Node. It serializes apply attempts and
uses dedicated Caddy protocol messages over the existing ZeroMQ/CURVE transport.
The Agent validates, applies, and recovers configuration through a durable
transaction. A failed Caddy apply does not roll back Service deployment.

The state machine, wire contract, canonical bytes, and recovery protocol are
specified in [the #207 implementation contract](../spec/207-caddy-configuration-reconciliation.md).

## Consequences

### Positive

- Caddy has an infrastructure lifecycle independent of Service Catalog outcomes.
- Immutable configuration history and mutable delivery history make late results
  and uncertain state auditable without rewriting a Version.
- Serialized attempts and predecessor hashes prevent stale commands from
  overwriting known or unknown Caddy state.
- Crash recovery preserves the prior committed configuration.

### Negative

- A failed or uncertain Caddy apply can leave a deployed Service without an
  active Ingress route until later remediation.
- The singleton Ingress Node remains an intentional availability limit.
- The Agent must maintain durable apply state in addition to the Caddyfile.

### Neutral

- External serving probes, heartbeat hash reporting, drift repair, operator
  rollback, retries after failed attempts, and Ingress Node failover remain
  outside this decision.

## Alternatives Considered

### Store Caddy state in the Service Catalog

- Pros: Reuses Service deployment persistence.
- Cons: Couples node infrastructure lifecycle to Service deployment rows.
- Why rejected: Caddy is a node-scoped Infrastructure Component with different
  identity, history, and failure semantics.

### Treat Caddy apply failures as Service deployment failures

- Pros: Makes routing availability part of one operation.
- Cons: Requires unsafe Service rollback and hides the independent Caddy failure.
- Why rejected: Deployment and ingress configuration are related but distinct
  lifecycles.

### Retry every reconciliation or elect a replacement Ingress Node

- Pros: May recover availability automatically.
- Cons: Repeatedly mutates uncertain state or silently changes the ingress
  endpoint.
- Why rejected: Repair and failover need their own explicit policies.

## References

- [#207 implementation contract](../spec/207-caddy-configuration-reconciliation.md)
- Forgejo issue #207 — Caddy configuration reconciliation and apply contract
- Forgejo epic #12 — Caddy configuration generation and delivery
- [ADR-0020](0020-caddy-for-ingress.md) — Caddy for ingress with generated Caddyfile
- [ADR-0024](0024-infrastructure-component-versioning.md) — Infrastructure component versioning
- [ADR-0036](0036-zeromq-unified-transport.md) — ZeroMQ as sole runtime transport between controller and agent
