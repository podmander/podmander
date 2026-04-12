# ADR-0030: Decentralized Logging via systemd Journal

**Status**: Accepted
**Date**: 2026-04-12

## Context

Operators need to view logs from services running across multiple nodes. A centralized log aggregation system (ELK, Loki, etc.) would provide a single query interface but adds significant infrastructure.

Key forces:

- The target audience runs small clusters (2–20 nodes). Dedicated log infrastructure is disproportionate.
- Services run as systemd units (see [ADR-0007](0007-services-as-systemd-units.md)), so logs are already in the systemd journal on each node.
- SSH access to nodes is already established (see [ADR-0010](0010-ssh-for-data-plane.md)).
- Operators who need centralized logging can deploy their own aggregation stack as Podmander services.

## Decision

Podmander does not aggregate logs centrally. Logs remain in the systemd journal on each node. The CLI queries logs via SSH, running `journalctl` on each node and merging results.

For services with multiple replicas, logs from all nodes are fetched in parallel and merged by timestamp.

Operators who need centralized logging can deploy their own stack (Promtail + Loki, Fluentd, etc.) as Podmander services with `placement = "all"`.

## Consequences

### Positive

- No log infrastructure to deploy, maintain, or pay for.
- Logs are always available — no ingestion delay, no pipeline to break.
- Uses existing infrastructure — systemd journal is already there, SSH is already configured.
- Operators choose their own aggregation stack if they need one — no vendor lock-in.
- Simple implementation — SSH + journalctl.

### Negative

- Multi-node log queries require SSH connections to each node — latency scales with node count.
- No full-text indexing — `journalctl --grep` is limited compared to Elasticsearch or Loki.
- Log retention is managed per-node via systemd journal configuration — not centrally controlled by Podmander.
- Historical log analysis across nodes is cumbersome without aggregation.

### Neutral

- `podmander logs --follow` streams via SSH, providing real-time log tailing.
- This decision does not prevent operators from deploying centralized logging — it just means Podmander does not require or manage it.

## Alternatives Considered

### Built-in log aggregation (controller collects logs)

- Pros: Single query point, centralized retention, no per-node SSH queries.
- Cons: Controller becomes a log sink — storage, ingestion pipeline, query engine. Significant scope increase. Controller availability affects log access.
- Why rejected: Violates the core philosophy. Log aggregation is a solved problem — operators should choose their preferred tool.

### Mandatory Loki/Promtail deployment

- Pros: Modern, efficient log aggregation. Good Grafana integration.
- Cons: Mandatory infrastructure dependency. Adds containers to every node. Storage for log data. Configuration complexity.
- Why rejected: Disproportionate for small clusters. Should be optional, not mandatory.

## References

- [ADR-0007](0007-services-as-systemd-units.md) — Services as systemd units (logs in journal)
- [ADR-0010](0010-ssh-for-data-plane.md) — SSH for data plane (used for log queries)
- [ADR-0031](0031-integration-first-monitoring.md) — Integration-first monitoring (same philosophy)
