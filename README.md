# Podmander

Container orchestration for multi-node deployments where Kubernetes is overkill. More than Docker Compose, less than Kubernetes.

Podmander generates configuration for proven tools — systemd, Podman, Caddy, Restic, ZFS — rather than reimplementing what they already do well.

## Status

**Early implementation.** Controller and agent daemons communicate over ZeroMQ with CURVE encryption. Agents register via join tokens and exchange heartbeats. Structured logging with level filtering and journald integration.

## Key Ideas

- Single controller, multiple worker agents
- Rootless Podman containers by default
- Custom TOML configuration (not Compose YAML)
- Quadlet files for systemd integration
- BTRFS/ZFS volume snapshots and rollback
- Encrypted secrets with libsodium
- Written in Ada

## Documentation

- [`docs/adr/`](docs/adr/) — Architecture Decision Records
- [`docs/spec/`](docs/spec/) — Specifications
- [`docs/plans/`](docs/plans/) — Implementation plans
- [`docs/brainstorms/`](docs/brainstorms/) — Design explorations
