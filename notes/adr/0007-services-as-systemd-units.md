# ADR-0007: Services as systemd Units, Not Agent Child Processes

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander agents deploy and manage services on each node. A fundamental question is the process relationship between the agent and the services it manages: should services be child processes of the agent, or independent processes managed by an external supervisor?

Key forces:

- Agent crashes must not interrupt running services. Workloads should survive agent restarts, upgrades, and crashes.
- The system already depends on systemd for agent lifecycle management.
- Agents need to rediscover existing workloads on restart without re-deploying them.
- Podman Quadlet files generate systemd units natively, so integration is straightforward.

## Decision

Services are systemd units, not agent child processes. The agent generates Quadlet files (`.container`, `.volume`, `.network`) that systemd translates into native service units. systemd owns the process lifecycle; the agent instructs systemd to start, stop, and restart units.

On restart, the agent rediscovers existing workloads by scanning Quadlet files on disk and querying Podman, without needing to re-deploy anything.

## Consequences

### Positive

- Workload continuity — agent crash or restart does not interrupt running services.
- systemd provides automatic restart, dependency ordering, and logging for free.
- Quadlet integration means Podmander generates declarative files rather than issuing imperative commands.
- Agents are stateless beyond Quadlet files on disk — no in-memory state to lose on crash.
- Standard tooling (`systemctl`, `journalctl`) works for debugging.

### Negative

- The agent cannot directly observe process signals or exit codes — it must query systemd and Podman for state.
- Quadlet file format constrains what can be expressed (though it covers the needed use cases).

### Neutral

- This decision is tightly coupled with the choice of Podman and Quadlet (see [ADR-0011](0011-podman-quadlet-for-containers.md)).

## Alternatives Considered

### Agent as process supervisor (child processes)

- Pros: Direct process control, immediate signal handling, simpler process tree.
- Cons: Agent crash kills all services. Agent restart requires re-launching every service. Agent must implement process supervision logic (restart policies, dependency ordering) that systemd already provides.
- Why rejected: Single point of failure for all workloads on a node. Reimplements functionality that systemd provides.

### Container runtime's built-in restart policies

- Pros: Podman supports `--restart=always` without external supervision.
- Cons: No dependency ordering between services. No integration with system-level services (CoreDNS, Caddy). Limited observability compared to systemd journal.
- Why rejected: Insufficient for orchestrating multiple services with dependencies and infrastructure components.
