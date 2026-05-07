# ADR-0024: Infrastructure Component Versioning

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander manages infrastructure components (Caddy, CoreDNS, Restic) alongside application services. These components have generated configuration files (Caddyfiles, zone files, Restic configs) that change when services are deployed, scaled, or reconfigured. Like services, operators may need to roll back a broken infrastructure configuration.

Key forces:

- A broken Caddyfile can take down all public-facing services. Quick rollback is critical.
- Infrastructure component configuration changes are tightly coupled to service deployments (e.g., adding a service with ingress updates the Caddyfile).
- The versioning model should be consistent with service versioning to reduce cognitive overhead.
- Drift detection (config file modified manually on a node) needs a reference to compare against.

## Decision

Infrastructure components use the same versioning model as services (see [ADR-0023](0023-per-service-monotonic-versioning.md)): monotonic version numbers, rollback creates a new version from old content, linear auditable history.

Each versioned infrastructure configuration tracks:

- Component type (`caddy`, `coredns`, `restic`)
- Node name (configuration is per-node)
- Config content and hash
- Source (`deploy`, `rollback`, `repair`)
- Lineage and outcome

Config hashes are reported in agent heartbeats. If the hash on disk does not match the expected version, the controller detects drift and can auto-repair (see [ADR-0006](0006-continuous-supervisor-loop.md)).

## Consequences

### Positive

- Consistent mental model — operators use the same `rollback` and `history` commands for services and infrastructure.
- Config hash comparison enables drift detection — manual edits on nodes are detected and corrected.
- Auditable history — every Caddyfile change is tracked with the reason and outcome.
- Quick recovery from broken configs — `podctl rollback caddy` restores the previous working configuration.

### Negative

- Infrastructure config changes are often side effects of service deploys, creating version churn (every service deploy that affects ingress creates a new Caddyfile version).
- Per-node versioning for CoreDNS zone files means N copies of version history (one per node), though the content is identical.

### Neutral

- Auto-repair for infrastructure drift means Podmander is the source of truth — manual config edits on nodes will be overwritten.

## Alternatives Considered

### No versioning for infrastructure (deploy-only, no rollback)

- Pros: Simpler — infrastructure configs are regenerated from current state, no history to maintain.
- Cons: A broken Caddyfile requires re-deploying the service that caused the change. No way to quickly restore the previous working config while investigating.
- Why rejected: Infrastructure failures are high-impact (broken Caddyfile = all public services down). Quick rollback is essential.

### Separate versioning model for infrastructure

- Pros: Could be optimized for the specific patterns of infrastructure configs (e.g., global versioning instead of per-component).
- Cons: Two versioning models to learn, implement, and maintain. Different CLI commands for service vs infrastructure rollback.
- Why rejected: Consistency with service versioning reduces cognitive overhead and implementation complexity.

## References

- [ADR-0023](0023-per-service-monotonic-versioning.md) — Per-service monotonic versioning (same model)
- [ADR-0006](0006-continuous-supervisor-loop.md) — Continuous supervisor loop (drift detection and auto-repair)
- [ADR-0020](0020-caddy-for-ingress.md) — Caddy for ingress (Caddyfile is a versioned infrastructure config)
- [ADR-0016](0016-coredns-daemonset.md) — CoreDNS daemonset (zone files are versioned infrastructure configs)
