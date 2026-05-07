# ADR-0001: Controller-Agent Topology

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander needs to orchestrate containers across multiple nodes. The fundamental question is how the system is structured: who decides what runs where, and who executes those decisions.

Three topologies were considered:

1. **On-demand CLI** — an operator tool that SSHes directly to nodes (like Kamal). No daemons.
2. **Peer-to-peer** — all nodes are equal participants in a consensus protocol.
3. **Controller-agent** — a single controller daemon makes decisions; agent daemons on each node execute them.

Key forces:

- The target audience (solo operators, small teams) needs self-healing without constant operator attention.
- The system should detect and repair drift automatically.
- The architecture should support future high availability without protocol changes.
- Operators should not need SSH access to every node from their workstation.

## Decision

We will use a controller-agent topology: a single controller daemon on a designated node, with an agent daemon on each worker node.

The controller owns scheduling, state management, and config generation. Agents execute commands, report status via heartbeats, and are stateless beyond Quadlet files on disk.

The CLI (`podctl`) talks to the controller API, not directly to nodes.

## Consequences

### Positive

- Continuous state awareness — the controller knows cluster state in real-time via agent heartbeats, not only when an operator runs a command.
- Self-healing — the supervisor loop detects and repairs drift without operator intervention.
- Foundation for HA — a running controller can participate in leader election; an on-demand CLI cannot. The shared-keypair design ensures agents need no protocol changes for HA.
- Decoupled operator location — the CLI talks to the controller; it does not need SSH access to every node.

### Negative

- Controller is a daemon that must stay running (systemd manages this).
- Agents are daemons on every node (also systemd-managed).
- More moving parts than a CLI-only approach.
- Single controller is a single point of failure until HA is implemented.

### Neutral

- Agent crash does not interrupt running services (they are systemd units, not agent child processes — see [ADR-0007](0007-services-as-systemd-units.md)).
- Controller crash prevents new deploys but does not affect running workloads.

## Alternatives Considered

### On-demand CLI (Kamal-style)

- Pros: Simpler — no daemons, no state management, fewer moving parts.
- Cons: No real-time state awareness, no self-healing, no foundation for HA. Operator must have SSH access to every node.
- Why rejected: Cannot detect or repair drift without operator intervention. Does not scale to the "deploy and walk away" model the target audience needs.

### Peer-to-peer

- Pros: No single point of failure, fully decentralized.
- Cons: Consensus protocols add significant complexity. Harder to reason about scheduling. Overkill for the target deployment size (2–20 nodes).
- Why rejected: Complexity disproportionate to the target scale. Controller HA (future) addresses the SPOF concern with less architectural overhead.
