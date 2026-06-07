# Architecture Decision Records

This directory contains the Architecture Decision Records (ADRs) for Podmander.

ADRs capture architecturally significant decisions — the *why* behind the system's design. For specifications on *how* things should work, see `notes/spec/`.

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0001](0001-controller-agent-topology.md) | Controller-agent topology | Accepted | 2026-04-12 |
| [0002](0002-ada-as-implementation-language.md) | Ada as implementation language | Accepted | 2026-04-12 |
| [0003](0003-sqlite-for-controller-state.md) | SQLite for controller state storage | Accepted | 2026-04-12 |
| [0004](0004-custom-toml-over-compose-yaml.md) | Custom TOML schema over Docker Compose YAML | Accepted | 2026-04-12 |
| [0005](0005-three-state-model.md) | Three-state model (desired, expected, actual) | Accepted | 2026-04-12 |
| [0006](0006-continuous-supervisor-loop.md) | Continuous supervisor loop for reconciliation | Accepted | 2026-04-12 |
| [0007](0007-services-as-systemd-units.md) | Services as systemd units, not agent child processes | Accepted | 2026-04-12 |
| [0008](0008-one-operation-per-service.md) | One concurrent operation per service | Accepted | 2026-04-12 |
| [0009](0009-zeromq-curve-for-control-plane.md) | ZeroMQ with CURVE encryption for control plane | Accepted | 2026-04-12 |
| [0010](0010-ssh-for-data-plane.md) | SSH for data plane and node access | Superseded by ADR-0036 | 2026-04-12 |
| [0011](0011-podman-quadlet-for-containers.md) | Podman with Quadlet for container execution | Accepted | 2026-04-12 |
| [0012](0012-rootless-containers-rootful-agent.md) | Rootless containers with rootful agent | Accepted | 2026-04-12 |
| [0013](0013-wireguard-optional-node-encryption.md) | WireGuard as optional node-level encryption | Accepted | 2026-04-12 |
| [0014](0014-wireguard-per-node-slash32-ips.md) | Per-node /32 WireGuard IPs from configurable pool | Accepted | 2026-04-12 |
| [0015](0015-node-local-wireguard-keypairs.md) | Node-local WireGuard keypair generation | Accepted | 2026-04-12 |
| [0016](0016-coredns-daemonset.md) | CoreDNS daemonset for service discovery | Accepted | 2026-04-12 |
| [0017](0017-hybrid-port-model.md) | Hybrid port model (auto-detect, explicit override) | Accepted | 2026-04-12 |
| [0018](0018-dns-hosts-envvars-ports.md) | DNS for host resolution, env vars for port injection | Accepted | 2026-04-12 |
| [0019](0019-per-stack-dns-zones.md) | Per-stack DNS zones with soft isolation | Accepted | 2026-04-12 |
| [0020](0020-caddy-for-ingress.md) | Caddy for ingress with generated Caddyfile | Accepted | 2026-04-12 |
| [0021](0021-local-master-key-libsodium.md) | Local master key with libsodium encryption | Accepted | 2026-04-12 |
| [0022](0022-agent-mediated-secret-delivery.md) | Agent-mediated secret delivery via podman secret create | Accepted | 2026-04-12 |
| [0023](0023-per-service-monotonic-versioning.md) | Per-service monotonic versioning (git-revert model) | Accepted | 2026-04-12 |
| [0024](0024-infrastructure-component-versioning.md) | Infrastructure component versioning | Accepted | 2026-04-12 |
| [0025](0025-filesystem-driver-abstraction.md) | Filesystem driver abstraction (directory, BTRFS, ZFS) | Accepted | 2026-04-12 |
| [0026](0026-btrfs-default-zfs-optional.md) | BTRFS as recommended default, ZFS as optional | Accepted | 2026-04-12 |
| [0027](0027-snapshots-linked-to-versions.md) | Snapshots linked to service versions | Accepted | 2026-04-12 |
| [0028](0028-operator-managed-state-backup.md) | Operator-managed state DB backup | Accepted | 2026-04-12 |
| [0029](0029-restic-and-native-send-for-backups.md) | Restic and native send for volume backups | Accepted | 2026-04-12 |
| [0030](0030-decentralized-journal-logging.md) | Decentralized logging via systemd journal | Accepted | 2026-04-12 |
| [0031](0031-integration-first-monitoring.md) | Integration-first monitoring (not built-in) | Accepted | 2026-04-12 |
| [0032](0032-ssh-based-node-bootstrap.md) | SSH-based node bootstrap with role-based installation | Abandoned | 2026-04-12 |
| [0033](0033-git-based-stack-collections.md) | Git-based stack collections with Jinja parameters | Accepted | 2026-04-12 |
| 0034 | CLI-to-controller communication protocol | Proposed | — |
| [0035](0035-database-layer-design.md) | Database layer design | Superseded by ADR-0037 | 2026-05-11 |
| [0036](0036-zeromq-unified-transport.md) | ZeroMQ as sole runtime transport between controller and agent | Accepted | 2026-05-17 |
| [0037](0037-database-only-state-access.md) | Database-only state access | Accepted | 2026-05-23 |
| [0038](0038-state-tracking-design.md) | State tracking design for MVP | Accepted | 2026-05-23 |
| [0039](0039-operator-cli-shares-agent-channel.md) | Operator CLI shares the agent control-plane channel | Accepted | 2026-06-06 |
| [0040](0040-node-as-first-class-domain-object.md) | Node as a first-class domain object, distinct from Agent | Proposed | 2026-06-07 |
