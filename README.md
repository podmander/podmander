# Podmander

Container orchestration for multi-node deployments where Kubernetes is overkill. More than Docker Compose, less than Kubernetes.

Podmander generates configuration for proven tools — systemd, Podman, Caddy, Restic, ZFS — rather than reimplementing what they already do well.

## Status

**Specification phase.** No code yet. See `docs/adr/` for architecture decisions and `docs/spec/` for specifications.

## Key Ideas

- Single controller, multiple worker agents
- Rootless Podman containers by default
- Custom TOML configuration (not Compose YAML)
- Quadlet files for systemd integration
- BTRFS/ZFS volume snapshots and rollback
- Encrypted secrets with libsodium
- Written in Ada

## Documentation

- [`docs/adr/`](docs/adr/README.md) — Architecture Decision Records (why decisions were made)
- [`docs/spec/`](docs/spec/) — Specifications (how things should work)
- [`docs/domains.md`](docs/domains.md) — Entity relationships and glossary
- [`docs/considerations.md`](docs/considerations.md) — Features not yet specified
- [`docs/brainstorms/`](docs/brainstorms/) — Design explorations
