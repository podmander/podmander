# ADR-0016: CoreDNS Daemonset for Service Discovery

**Status**: Accepted
**Date**: 2026-04-12

## Context

Services in a Podmander fleet need to discover each other across node boundaries. The discovery mechanism must resolve service names to the correct node addresses, handle service moves transparently, and survive controller unavailability.

Key forces:

- DNS resolution should not require a network hop to a remote server — latency matters for frequently resolved names.
- If the controller goes down, existing services should still be able to discover each other using the last known placement data.
- The solution should follow Podmander's "generate, don't execute" philosophy — the controller generates configuration, a proven tool serves it.
- Zone data changes when placements change (deploy, scale, move, node add/remove). Distribution must use existing infrastructure.

## Decision

We will deploy CoreDNS as a daemonset — one instance per node, running as a Podman container. The controller generates zone files and distributes them to all nodes via SSH. CoreDNS auto-reloads zone files on change (configurable interval, default 5 seconds).

Each stack gets a zone (`<stack>.podmander.internal`). External DNS resolution falls through to the system resolver.

When WireGuard is enabled (see [ADR-0013](0013-wireguard-optional-node-encryption.md)), A records resolve to WireGuard IPs. When disabled, they resolve to host IPs.

## Consequences

### Positive

- Local resolution — no network hop for DNS queries, consistent low latency.
- Survives controller unavailability — existing zone data continues to serve until placements change.
- Consistent with the per-node agent model — one CoreDNS per node mirrors one agent per node.
- Zone file generation and SSH distribution reuse existing mechanisms (same as Quadlet and Caddyfile distribution).
- CoreDNS is a single static binary (available as OCI image), minimal configuration (Corefile can be ~5 lines), and supports file-based zone reload.

### Negative

- Zone files must be distributed to every node when placements change — more SSH transfers than a singleton approach.
- N instances of CoreDNS consume more resources than a single instance (though each instance is lightweight).
- Zone data can be briefly stale (up to the reload interval) after a placement change.

### Neutral

- CoreDNS follows the same generate-and-reload pattern as Caddy (Caddyfile) and Restic (config files).
- Containers reach CoreDNS via a per-stack Podman network with the local CoreDNS instance configured as DNS server.

## Alternatives Considered

### Singleton CoreDNS (one instance for the fleet)

- Pros: Simpler — one instance to manage, one copy of zone files.
- Cons: Single point of failure for DNS. Every DNS query requires a network hop. Controller unavailability plus CoreDNS failure leaves the fleet with no discovery.
- Why rejected: SPOF for DNS is unacceptable. Network hop latency for every resolution adds unnecessary overhead.

### Embedded DNS in the agent

- Pros: No additional container — DNS served directly by the agent process.
- Cons: Agents are written in Ada; embedding a DNS server adds complexity and a new protocol implementation to maintain. CoreDNS is proven and well-tested. Agent crash would take down DNS.
- Why rejected: Reimplements proven functionality. Agent crash would affect both orchestration and DNS, increasing blast radius.

### SRV records instead of A records

- Pros: SRV records can encode both host and port in a single query, eliminating the need for env var port injection.
- Cons: Poor client support — most application frameworks and database drivers do not use SRV records for connection establishment. Would require application-level changes.
- Why rejected: Insufficient client support. DNS A records for hosts combined with env vars for ports has universal application compatibility.

## References

- [ADR-0017](0017-hybrid-port-model.md) — Hybrid port model (port allocation that CoreDNS serves)
- [ADR-0018](0018-dns-hosts-envvars-ports.md) — DNS for hosts, env vars for ports
- [ADR-0019](0019-per-stack-dns-zones.md) — Per-stack DNS zones
- [ADR-0013](0013-wireguard-optional-node-encryption.md) — WireGuard IPs in DNS when enabled
