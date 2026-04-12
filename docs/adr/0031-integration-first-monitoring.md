# ADR-0031: Integration-First Monitoring (Not Built-In)

**Status**: Accepted
**Date**: 2026-04-12

## Context

Operators need to monitor cluster health: are services running, are nodes reachable, are there divergences between expected and actual state? A built-in monitoring system would provide a complete solution but adds significant scope and infrastructure.

Key forces:

- Podmander is an orchestrator, not a monitoring system. Purpose-built tools (Prometheus, Alertmanager, Uptime Kuma) exist and are proven.
- The CLI already queries cluster state for `podmander status`. Machine-readable output enables integration with external tools.
- The target audience may already have monitoring infrastructure. Podmander should integrate with it, not replace it.
- Automated remediation (webhook-triggered `podmander repair`) needs a non-interactive CLI mode.

## Decision

Podmander provides integration hooks for external monitoring systems rather than building its own. Specifically:

- **`podmander status --json`** — machine-readable cluster state for monitoring ingestion.
- **Exit codes** — `0` (healthy), `1` (divergences), `2` (node unreachable), `3` (error) — for scripted health checks.
- **`--yes` flag** — non-interactive mode for all state-changing commands, enabling webhook-triggered remediation.
- **Health check configuration** — optional per-service health endpoints checked during deploys and status queries.

The recommended monitoring stack (Prometheus + Alertmanager + Grafana + Node Exporter) can be deployed as Podmander services.

## Consequences

### Positive

- No monitoring infrastructure to build, deploy, or maintain within Podmander.
- Operators use tools they already know — Prometheus, Uptime Kuma, systemd timers, cron.
- JSON output and exit codes provide clean integration surfaces for any monitoring tool.
- `--yes` flag enables automated remediation from alerting webhooks.
- Monitoring stack deployed as Podmander services benefits from the same orchestration (rollback, scaling, etc.).

### Negative

- No out-of-the-box monitoring — operators must set up their own monitoring integration.
- No pre-built dashboards or alert rules (future extension).
- No native Prometheus metrics endpoint — operators must wrap `podmander status --json` in an exporter script (native endpoint is a future extension).

### Neutral

- The monitoring stack (Prometheus, Grafana, etc.) can be deployed as Podmander services, dogfooding the orchestrator.
- Health checks are optional — services without health endpoints still report basic status (running/stopped).

## Alternatives Considered

### Built-in monitoring dashboard

- Pros: Out-of-the-box visibility, no external tools needed.
- Cons: Web UI, metrics storage, alerting engine — massive scope increase. Competing with purpose-built tools on their home turf.
- Why rejected: Monitoring is a solved problem. Building a bespoke solution would be inferior to integrating with proven tools.

### Built-in Prometheus exporter

- Pros: Native metrics endpoint, cleaner integration than JSON-to-exporter wrapper scripts.
- Cons: Adds a dependency on the Prometheus exposition format. Implementation effort for the initial release.
- Why rejected: Not rejected — deferred. A native `podmander status --prometheus` endpoint is planned as a future extension. The JSON output is sufficient for the initial release.

## References

- [ADR-0030](0030-decentralized-journal-logging.md) — Decentralized journal logging (same philosophy)
- [ADR-0006](0006-continuous-supervisor-loop.md) — Continuous supervisor loop (detects divergences that monitoring surfaces)
