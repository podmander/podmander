# Podmander

Container orchestration for multi-node deployments where Kubernetes is overkill. More than Docker Compose, less than Kubernetes.

Podmander generates configuration for proven tools — systemd, Podman, Caddy, Restic, ZFS — rather than reimplementing what they already do well.

## Status

**Early implementation.** See the [issue queue](https://code.monospacementor.com/podmander/podmander/issues) and [closed PRs](https://code.monospacementor.com/podmander/podmander/pulls?q=is%3Aclosed) for progress.

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
