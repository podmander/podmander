# ADR-0020: Caddy for Ingress with Generated Caddyfile

**Status**: Accepted
**Date**: 2026-04-12

## Context

Services in a Podmander fleet need to be reachable from the public internet via HTTP/HTTPS. This requires a reverse proxy on the ingress node(s) that terminates TLS, routes requests to backend services, and handles certificate management.

Key forces:

- TLS certificate management should be automatic — operators should not manage Let's Encrypt renewals manually.
- The proxy must support the "generate, don't execute" philosophy — Podmander generates configuration, the proxy serves it.
- Configuration should be simple enough that operators can understand and debug it.
- The proxy runs as a Quadlet on ingress nodes, consistent with all other managed components.

## Decision

We will use Caddy as the reverse proxy for public-facing ingress. The controller generates a Caddyfile from service ingress declarations in the stack TOML and delivers it to ingress nodes over the existing ZeroMQ/CURVE channel. Caddy reloads on configuration change.

Caddy runs as a Quadlet on ingress node(s), following the same generate-then-execute pattern as CoreDNS zone files and Restic configuration.

## Consequences

### Positive

- Automatic HTTPS via Let's Encrypt with zero configuration — Caddy handles certificate issuance, renewal, and OCSP stapling.
- Simple Caddyfile syntax — easy to understand and debug.
- Single binary, available as an OCI image — minimal dependencies.
- API available for dynamic updates if needed in the future.
- Same generate-and-reload pattern as other infrastructure components (CoreDNS, Restic).

### Negative

- Caddy's configuration model is less flexible than Nginx for advanced routing scenarios.
- Less community adoption than Nginx — fewer community-maintained configuration examples.
- Ingress nodes typically need rootful mode for ports 80/443 (see [ADR-0012](0012-rootless-containers-rootful-agent.md)).

### Neutral

- Caddyfile versioning follows the same infrastructure component versioning model (see [ADR-0024](0024-infrastructure-component-versioning.md)).
- Internal ingress (services reachable across nodes but not publicly) is a separate, deferred concern.

## Alternatives Considered

### Nginx

- Pros: Industry standard, extremely flexible configuration, massive community, extensive documentation.
- Cons: No automatic TLS — requires Certbot or similar for Let's Encrypt. Configuration syntax is more complex. No native API for dynamic updates.
- Why rejected: Manual TLS management adds operational burden that conflicts with the target audience's need for simplicity. Caddy's automatic HTTPS is a significant usability advantage.

### Traefik

- Pros: Automatic TLS, dynamic configuration via labels/API, built-in service discovery.
- Cons: Configuration is more complex (YAML/TOML with middleware chains). Built-in service discovery overlaps with Podmander's CoreDNS-based discovery. More opinionated architecture.
- Why rejected: Overlapping service discovery creates confusion. Podmander already handles routing decisions — the proxy should just execute them. Caddy's simpler model is a better fit.

### HAProxy

- Pros: High performance, battle-tested at scale, rich load balancing options.
- Cons: No automatic TLS. Configuration is complex and imperative. Overkill for the target deployment size.
- Why rejected: Complexity and manual TLS management are unnecessary for the target audience.

## References

- [ADR-0024](0024-infrastructure-component-versioning.md) — Infrastructure component versioning (Caddyfile is versioned)
- [ADR-0012](0012-rootless-containers-rootful-agent.md) — Rootless containers with rootful agent (ingress nodes are typically rootful)
- [ADR-0036](0036-zeromq-unified-transport.md) — ZeroMQ as sole runtime transport
