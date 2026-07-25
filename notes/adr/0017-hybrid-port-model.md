# ADR-0017: Hybrid Port Model (Auto-Detect, Explicit Override)

**Status**: Accepted
**Date**: 2026-04-12

## Context

Container services need host ports for inter-service communication. Traditional approaches require operators to declare every port explicitly, which is tedious and error-prone. But fully dynamic port allocation makes configuration opaque and breaks expectations.

Key forces:

- Operators should not have to manage ports for common cases — container images already declare their ports via `EXPOSE`.
- Some services have hard port requirements (e.g., a database that must listen on 5432 for client compatibility).
- Port conflicts arise when multiple services want the same host port on the same node.
- Replicated services need consistent ports across all replicas — mixed ports would break DNS round-robin.
- Once assigned, ports should remain stable across service moves to avoid unnecessary dependent restarts.

## Decision

We will use a hybrid port model with three tiers:

1. **Explicit port** — operator declares a specific port. This is a hard scheduling constraint. If the port is unavailable on enough nodes, the deploy fails.
2. **Auto-detected port** — no port declared; Podmander reads the `EXPOSE` directive from the container image. The scheduler tries the natural port first. If unavailable, it auto-assigns from a managed range (default 30000–32767, configurable).
3. **No port** — no declaration and no `EXPOSE` in the image. The service deploys without port allocation or service discovery. Valid for batch jobs and cron tasks.

Multiple named ports use complete published host-to-container mappings, for
example `ports = { http = { host = 8080, container = 8080 } }`. Each is tracked
as a separate scheduling constraint. The older `ports = { http = 8080 }`
shorthand is unsupported because it cannot express both ports. Existing unnamed
string and structured port forms remain valid for Services without Ingress.

Port assignments are stable: once assigned, a port stays the same across moves. It only changes when forced (the only available node already uses that port). All replicas of a service use the same port.

## Consequences

### Positive

- Operators do not manage ports in the common case — images declare ports, Podmander handles allocation.
- Explicit ports are respected as hard constraints — operator intent is never silently overridden.
- Auto-assign fallback handles port conflicts without operator intervention.
- Port stability minimizes unnecessary restarts of dependent services.
- Replica port consistency ensures DNS round-robin works correctly.

### Negative

- Auto-assigned ports (30000–32767) are less predictable than natural ports — operators must use env vars or DNS, not hardcoded ports.
- Port reassignment (rare) triggers restarts of all dependent containers to update `_PORT` env vars.
- The scheduler must track port allocations per node, adding complexity to placement decisions.

### Neutral

- No-port services deploy silently without warnings — batch jobs and cron tasks are legitimate non-networked workloads.

## Alternatives Considered

### Fixed ports only (operator must declare every port)

- Pros: Fully explicit, no surprises.
- Cons: Tedious for common cases. Forces operators to manage port assignments manually. Port conflicts require manual resolution.
- Why rejected: Bad operator experience. Most services use their well-known ports; requiring explicit declaration for every one is unnecessary friction.

### Dynamic ports only (always auto-assign)

- Pros: No port conflicts — every service gets a unique port from the managed range.
- Cons: Ports are always opaque — operators and external tools cannot predict them. Breaks expectations for services with well-known ports (PostgreSQL on 5432, Redis on 6379).
- Why rejected: Inconsistent with operator expectations. Auto-assigned ports for services that could use their natural port is confusing.

### Virtual IPs per service

- Pros: Eliminates port conflicts entirely — each service gets its own IP and can use any port.
- Cons: Requires a network overlay or IP address management. Conflicts with the node-level networking model (see [ADR-0013](0013-wireguard-optional-node-encryption.md)). Significant implementation complexity.
- Why rejected: Overkill for the target deployment size. Deferred as a future extension if port conflicts become a persistent problem.

## References

- [ADR-0018](0018-dns-hosts-envvars-ports.md) — DNS for hosts, env vars for ports (how ports are communicated)
- [ADR-0016](0016-coredns-daemonset.md) — CoreDNS daemonset (serves the DNS side of discovery)
