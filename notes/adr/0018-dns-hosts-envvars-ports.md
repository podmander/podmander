# ADR-0018: DNS for Host Resolution, Env Vars for Port Injection

**Status**: Accepted
**Date**: 2026-04-12

## Context

Service discovery has two components: finding where a service is running (host) and on which port. These have different change characteristics:

- **Hosts change** when services move between nodes (scaling, node drain, failure recovery). This can happen at any time.
- **Ports rarely change** — once assigned, ports are stable across moves (see [ADR-0017](0017-hybrid-port-model.md)). Port changes are rare and forced.

The discovery mechanism should minimize container restarts when placements change.

Key forces:

- Host changes should not require restarting dependent containers.
- Port information must be accessible to applications that cannot perform DNS lookups for port data (most applications — SRV record support is rare).
- The mechanism must work with any application framework without code changes.

## Decision

We will use DNS A records for host resolution and environment variables for port injection. These are split because they have different update characteristics:

- **`<SERVICE>_HOST`** contains a DNS name (e.g., `postgres.webapp.podmander.internal`), not a resolved IP. When a service moves, CoreDNS updates the A record. The DNS name in the env var stays the same — no container restart needed.
- **`<SERVICE>_PORT`** contains the allocated port (e.g., `5432`). Injected into Quadlet files. Only changes on port reassignment, which triggers Quadlet regeneration and container restart.

For multi-port services: `<SERVICE>_<NAME>_HOST` and `<SERVICE>_<NAME>_PORT` (e.g., `GATEWAY_HTTP_PORT=8080`).

Dependencies are declared via `depends_on` in the stack TOML. Env var injection is stack-scoped — `depends_on` can only reference services within the same stack.

## Consequences

### Positive

- Host changes are transparent — DNS updates propagate without container restarts (within TTL).
- Port information is universally accessible — every application framework reads environment variables.
- Restarts only occur on port reassignment, which is rare.
- Env var naming is simple and predictable: uppercase, hyphens to underscores (`my-api` → `MY_API_HOST`).

### Negative

- DNS TTL (default 5 seconds) introduces a brief window where stale host data may be returned after a service move.
- Applications that cache DNS aggressively (e.g., JVM with default security manager settings) may see longer staleness.
- Stack-scoped injection means cross-stack service dependencies are not supported via env vars — cross-stack resolution requires manual FQDN configuration.

### Neutral

- Env vars are injected into generated Quadlet files — no runtime injection mechanism needed.

## Alternatives Considered

### DNS SRV records (host and port in one query)

- Pros: Single query returns both host and port. No env vars needed.
- Cons: Most application frameworks and database drivers do not support SRV record lookups for connection establishment. Would require application-level changes or a sidecar proxy.
- Why rejected: Insufficient client support. Would force application changes on operators, violating the goal of working with any application unchanged.

### Environment variables only (no DNS)

- Pros: Single mechanism. Everything in env vars. Simple to understand.
- Cons: Host changes require regenerating Quadlet files and restarting all dependent containers. For a fleet where services move frequently (scaling, drain, failure), this causes excessive restarts.
- Why rejected: Container restarts on every host change is unacceptable churn.

### Service mesh / sidecar proxy

- Pros: Transparent service discovery, load balancing, retries, circuit breaking.
- Cons: Massive complexity — sidecar container per service, control plane, traffic interception. Overkill for the target deployment size.
- Why rejected: Disproportionate complexity for small-scale deployments. DNS + env vars solve the discovery problem adequately.

## References

- [ADR-0016](0016-coredns-daemonset.md) — CoreDNS daemonset (serves DNS A records)
- [ADR-0017](0017-hybrid-port-model.md) — Hybrid port model (determines port values)
- [ADR-0019](0019-per-stack-dns-zones.md) — Per-stack DNS zones (scoping)
