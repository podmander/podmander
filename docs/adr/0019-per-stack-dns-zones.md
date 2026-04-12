# ADR-0019: Per-Stack DNS Zones with Soft Isolation

**Status**: Accepted
**Date**: 2026-04-12

## Context

A Podmander fleet can run multiple stacks (groups of related services). Services within a stack need to discover each other easily, but the question is whether services in different stacks should be isolated or share a single discovery namespace.

Key forces:

- Name collisions are likely if multiple stacks share a namespace — two stacks may each define a `postgres` or `redis` service.
- Full isolation blocks legitimate cross-stack communication patterns (shared infrastructure, API composition).
- The isolation boundary should match the existing configuration boundary (stacks are the unit of deployment and configuration).

## Decision

Each stack gets its own DNS zone: `<stack>.podmander.internal`. Containers in a stack get their stack's zone as the DNS search domain, so short names (e.g., `postgres`) resolve within the same stack.

Cross-stack resolution is possible via FQDN (`postgres.other-stack.podmander.internal`) but no env vars are injected across stack boundaries. This is "soft" isolation — not enforced at the DNS level, just not convenient.

Hard isolation (blocking cross-stack resolution entirely) is deferred to future namespace work.

## Consequences

### Positive

- Name collisions are avoided — each stack's `postgres` resolves to its own instance.
- Short names work within a stack — containers query `postgres`, not `postgres.webapp.podmander.internal`.
- Cross-stack communication is possible when genuinely needed, without special configuration.
- Aligns with the stack as the natural isolation boundary in Podmander's configuration model.

### Negative

- Cross-stack dependencies require manual FQDN configuration — no env var injection across stacks.
- Soft isolation is not a security boundary — a compromised service can resolve names in any stack.
- Zone file count scales with the number of stacks — many small stacks create many zone files (though each is tiny).

### Neutral

- Hard isolation via DNS filtering or namespace-scoped zones is a natural future extension that does not require architectural changes.
- External DNS resolution falls through to the system resolver — containers can resolve public DNS names alongside stack-internal names.

## Alternatives Considered

### Single shared zone for all stacks

- Pros: Simpler — one zone, one search domain. Cross-stack discovery is natural.
- Cons: Name collisions between stacks (multiple `postgres` services). Requires globally unique service names, which constrains stack authors.
- Why rejected: Name collisions are a practical certainty in multi-stack deployments. Globally unique naming is an unreasonable constraint on stack authors.

### Per-stack CoreDNS instances (one CoreDNS per stack per node)

- Pros: True isolation — each stack's DNS is physically separate.
- Cons: Resource overhead scales with stacks × nodes. Significantly more containers to manage. Cross-stack resolution would require DNS forwarding rules between instances.
- Why rejected: Disproportionate resource overhead. Soft isolation via zones achieves the practical goal without multiplying CoreDNS instances.

## References

- [ADR-0016](0016-coredns-daemonset.md) — CoreDNS daemonset (one instance per node serves all zones)
- [ADR-0018](0018-dns-hosts-envvars-ports.md) — DNS for hosts, env vars for ports
