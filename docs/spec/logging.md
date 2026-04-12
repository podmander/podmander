# Logging Specification

Log access for deployed services.

For architectural decisions and rationale, see:
- [ADR-0030](../adr/0030-decentralized-journal-logging.md) — Decentralized logging via systemd journal

## Architecture

Logs remain in the systemd journal on each node. The CLI queries logs via SSH.

## CLI Query Interface

```bash
podmander logs api --since 1h --grep "error"
podmander logs api --node web-1            # Specific node only
podmander logs api --follow                # Tail logs (streams via SSH)
```

Under the hood:
```
ssh user@web-1 "journalctl --user -u api.service --since '1 hour ago' --grep error"
ssh user@web-2 "journalctl --user -u api.service --since '1 hour ago' --grep error"
# Results merged and displayed
```

For services with multiple replicas, logs from all nodes are fetched and merged
by timestamp.

## External Aggregation

Operators who need centralized logging can deploy their own stack as Podmander
services:

```toml
[service.promtail]
placement = "all"       # One per node
image = "grafana/promtail:latest"
# Configure to scrape journal and send to Loki
```

## Open Items

- Log retention policies (systemd journal config)
- Structured logging conventions for services
- Performance: parallel SSH queries for multi-node log fetching
