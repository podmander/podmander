# Configuration Specification

Custom TOML schema for declaring services, volumes, and cluster settings.

For architectural decisions and rationale, see:
- [ADR-0004](../adr/0004-custom-toml-over-compose-yaml.md) — Custom TOML schema over Docker Compose YAML
- [ADR-0033](../adr/0033-git-based-stack-collections.md) — Git-based stack collections with Jinja parameters

## Service Definitions

```toml
[service.api]
image = "myapp"
replicas = 3              # Scheduler distributes across nodes

[service.postgres]
singleton = true          # Exactly one instance

[service.node-exporter]
placement = "all"         # DaemonSet-style, one per node
```

Services declare dependencies, exposed ports, secrets, volumes, health checks,
resource limits, and placement constraints.

## CLI Shape

```bash
podmander deploy cluster.toml
podmander status
podmander logs <service>
podmander scale <service> <count>
podmander secret set|list|rm
podmander node list|label|drain|rm
podmander backup status|run|list
podmander volume restore <name>
podmander convert docker-compose.yml  # Migration helper
```

## Stack Collections

Stack definitions can be shared via git repositories. Clone a repository
containing TOML stack files, then deploy from the local path:

```bash
git clone https://github.com/example/homelab-stacks.git
podctl deploy ./homelab-stacks/monitoring/grafana.toml
```

No special tooling required — `podctl deploy <file>` works with any local path.
Operators manage updates via standard git workflows.

### Parameters

Shared stacks declare parameters for customization:

```toml
[params.domain]
required = true
description = "Domain name for ingress and TLS certificate"

[params.replicas]
default = 2
description = "Number of app replicas"

[service.app]
image = "myapp:latest"
replicas = {{ replicas }}

[service.app.ingress]
domain = "{{ domain }}"
```

Values are supplied via a separate params file:

```bash
podctl deploy ./stacks/myapp.toml --params ./my-params.toml
```

## Open Items

- Full TOML schema specification
- Detailed CLI/API design
- Multi-file configuration structure (splitting large configs across files)
- Schema validation rules and error messages
- Stack parameters: full `[params]` schema, params file format, validation rules
