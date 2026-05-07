# Monitoring Specification

Metrics, observability, and integration with external monitoring systems.

For architectural decisions and rationale, see:
- [ADR-0031](../adr/0031-integration-first-monitoring.md) — Integration-first monitoring

## Cluster Status

### Human-Readable Output

```bash
podctl status
```

Shows cluster health with divergence detection:
- Services: running, stopped, version mismatches
- Nodes: reachable, unreachable
- Volumes: mounted, snapshot status

### Machine-Readable Output

```bash
podctl status --json
```

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "nodes": [
    {
      "name": "web-1",
      "host": "192.168.1.10",
      "reachable": true,
      "services": [
        {
          "name": "api",
          "status": "running",
          "version": "v5",
          "expected_version": "v5",
          "healthy": true
        }
      ]
    }
  ],
  "divergences": [],
  "summary": {
    "nodes_total": 3,
    "nodes_reachable": 3,
    "services_total": 5,
    "services_healthy": 5,
    "divergence_count": 0
  }
}
```

### Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | All services healthy, no divergences |
| 1 | Divergences detected (expected != actual) |
| 2 | Node unreachable |
| 3 | Command error (SSH failure, invalid config) |

## Non-Interactive Mode

All state-changing commands support `--yes` for automated execution:

```bash
podctl repair --yes                    # Fix all divergences without prompting
podctl repair --service=api --yes      # Fix specific service
podctl restart api --yes               # Restart service
podctl deploy cluster.toml --yes       # Deploy without confirmation
```

## Integration Patterns

### Pattern 1: Periodic Status Check

```bash
# /etc/cron.d/podmander-status
*/5 * * * * operator /usr/local/bin/podctl status --json >> /var/log/podmander-status.json
```

### Pattern 2: Prometheus + Alertmanager

Create a status exporter script, configure Alertmanager webhooks to trigger
`podctl repair --yes` for automated remediation.

### Pattern 3: Uptime Kuma

Configure Uptime Kuma to run `podctl status` via SSH or exec monitor and
alert on non-zero exit codes.

### Pattern 4: Systemd Timer Watchdog

```ini
# ~/.config/systemd/user/podmander-watchdog.timer
[Unit]
Description=Podmander health check

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# ~/.config/systemd/user/podmander-watchdog.service
[Unit]
Description=Podmander health check

[Service]
Type=oneshot
ExecStart=/usr/local/bin/podctl status
```

## Service Health Checks

```toml
[service.api.health]
endpoint = "/health"
port = 3000
timeout = 5
```

When configured, `podctl status` queries the health endpoint for each running
instance and includes health status in output.

## Recommended Stack

| Component | Purpose |
|-----------|---------|
| Prometheus | Metrics collection |
| Alertmanager | Alert routing |
| Grafana | Visualization |
| Node Exporter | System metrics (CPU, memory, disk) |

All deployable as Podmander services.

## Open Items

- Native Prometheus metrics endpoint (`podctl status --prometheus`)
- Webhook server mode for receiving alerts directly
- Pre-built Grafana dashboard
- Health check protocols beyond HTTP (TCP, gRPC)
