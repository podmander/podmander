# ADR-0040: Node as a First-Class Domain Object, Distinct from Agent

**Date**: 2026-06-07

## Context

`DOMAIN.md` has always separated two concepts: a **Node** is a machine with a
unique identity, labels, and capabilities; an **Agent** is the Podmander process
running on that node. Placement is described as targeting a Node
([ADR-0001](0001-controller-agent-topology.md)). The code never honored that
separation.

Three identifiers became tangled:

- `Agent_Id` (`Integer`) — the `agents` table primary key. The Service Catalog
  stores it as the placement target.
- `Node_Id` (`Unbounded_String`) — despite the name, this is the agent's ZeroMQ
  ROUTER routing identity (`H.Identity`), assigned at registration and echoed in
  heartbeats. It is a transport concept, not a node identity.
- The domain **Node** — has no representation in code at all.

So the word "Node" already appears in the code, attached to a *transport*
concept, while the thing the glossary calls a Node is absent. The Scheduler and
its pluggable Scheduling Strategy ([ADR-0006](0006-continuous-supervisor-loop.md)
context) select and return an `Agent_Option`; the catalog keys on `Agent_Id`.
Issue #139 surfaced this as a terminology smell.

The forces shaping the decision:

- The MVP has node↔agent as 1:1, no node labels or capabilities, and trivial
  placement (deploy to the connected agent). Nothing *today* needs a Node.
- Every envisioned Scheduling Strategy beyond *First Available* — least-loaded,
  fewest-services, label-matching — selects on **node** characteristics, not
  agent connection state. The selection target is conceptually a Node.
- "Agent" is a protocol-layer detail: how the controller reaches a machine. It
  should not be the avatar of the machine throughout the domain code.
- The transport string misnamed `node_id` actively teaches the wrong model.
- The system has no production users, so no migration or compatibility
  constraints apply.

## Decision

We will model the **Node** as a first-class domain object, distinct from the
**Agent**, and make the Node — not the Agent — the unit of placement.

- **Two entities.** A durable `nodes` entity (the scheduling target) is
  associated 1:1 with a connection-scoped `agents` entity. The Node carries
  identity and, eventually, scheduling-relevant characteristics (labels,
  capabilities); the Agent carries connection state (`State`, `Last_Seen`) and
  the transport routing identity. Connection churn touches only the Agent; the
  Node is stable.
- **The `nodes` entity stays minimal.** It is created now with only the columns
  it needs today (identity). `labels` and `capabilities` columns are deferred
  until the first Strategy that reads them — the entity is the seam, not a
  speculative schema.
- **Identity naming** is settled to break the collision:
  - `Node_Id` — the Node identity; the Service Catalog's placement target.
  - `Agent_Id` — the Agent record key; confined to the protocol/agent layer.
  - `Connection_Id` — the ZeroMQ routing identity, renamed from the misnamed
    `node_id`. The wire field becomes `connection_id`.
- **The Service Catalog references a Node.** The catalog's `Agent_Id` becomes
  `Node_Id`. The Scheduler and Scheduling Strategy select a Node
  (`Select_Node`, `Node_Option`), not an agent.
- **Agent-first lifecycle.** A Node comes into existence when its agent enrolls
  via join token; its durable identity is the operator-supplied machine name. A
  reconnecting agent re-associates with the same Node. There is no separate
  node-declaration step.
- **Routing resolves Node to Agent.** To deliver a `Deployment_Command`, the
  controller resolves the catalog's Node to its associated Agent and sends to
  that Agent's `Connection_Id`. A deploy to a Node whose agent is currently
  disconnected waits, exactly as today.

This ADR captures the model and terminology. The code changes that realize it
(the `nodes`/`agents` split, the `Agent_Id`→`Node_Id` catalog change, the
`Select_Node`/`Node_Option` rename, and the `Connection_Id` rename plus wire
field) are tracked in a separate issue.

## Consequences

### Positive

- The domain code stops using the Agent as the machine's avatar. "Agent is a
  protocol-layer detail" becomes true in storage and types, not just in prose.
- Node-characteristic strategies get their natural home (`nodes.labels`,
  `nodes.capabilities`) without reworking the agent connection.
- The transport identity is named for what it is. "Node" in the code now means
  the domain Node, consistently.
- The Node outlives any single agent connection, so placement decisions survive
  agent restarts without re-scheduling.

### Negative

- A schema and type change rippling across the protocol, controller, catalog,
  and strategy layers — larger than the terminology smell that prompted it.
- Two tables and a join where one row exists today, for a 1:1 relationship that
  carries no extra Node attributes yet.
- The wire field rename (`node_id` → `connection_id`) means agent and controller
  must ship together. Acceptable pre-release, where both ends are built as a
  unit.

### Neutral

- For MVP the `nodes` entity holds little more than an identity; its value is the
  seam it establishes, not the data it stores yet.
- Node-first declarative provisioning (pre-declaring a node with labels so an
  agent binds to it on enrollment) remains possible later as an additive change
  to the same `nodes` entity, not a rework.

## Alternatives Considered

### Align the code on "Agent" and keep Node as documentation only

- Pros: no schema or behavior change; smallest possible diff; matches what the
  code physically has today (a registered agent connection).
- Cons: entrenches the Agent as the placement target, exactly the avatar problem
  we want to avoid; every future node-characteristic strategy would have to
  unwind it; leaves the misnamed transport `node_id` in place.
- Why rejected: it satisfies #139's letter ("no behavior change") while
  cementing the conceptual error the issue exists to fix.

### Single table — relabel the `agents` row as the node

- Pros: less ceremony than two tables; no join.
- Cons: re-fuses the two concepts we are separating; durable node identity and
  ephemeral connection state share a row with conflicting lifecycles.
- Why rejected: it cannot express "the agent is the protocol layer" in storage;
  the separation would survive only in naming.

### Node-first declarative provisioning now

- Pros: labels become operator-owned metadata; placement can be validated before
  any agent is live.
- Cons: requires a declare-and-bind operator workflow and label management the
  MVP has no use for.
- Why rejected: speculative for the current milestone. Agent-first is
  forward-compatible with adding this later.

## References

- [ADR-0001](0001-controller-agent-topology.md) — Controller-agent topology;
  placement targets a node
- [ADR-0036](0036-zeromq-unified-transport.md) — ZeroMQ routing identity
  (`Connection_Id`)
- [ADR-0038](0038-state-tracking-design.md) — Service Catalog as the placement
  and state record
- `DOMAIN.md` — Node, Agent, Scheduler, Scheduling Strategy, Service Catalog;
  Node-vs-Agent entry under Flagged Ambiguities
- Issue #139 — Node-vs-agent terminology resolution
