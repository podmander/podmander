# ADR-0025: Filesystem Driver Abstraction (Directory, BTRFS, ZFS)

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander manages persistent volumes for services. Different deployment environments have different filesystem capabilities — some have copy-on-write filesystems with snapshot support, others have standard ext4/xfs filesystems.

Key forces:

- Snapshot-capable volumes enable linking data state to service versions, making "code plus data" rollback possible (see [ADR-0027](0027-snapshots-linked-to-versions.md)).
- Not all deployments can or want to use advanced filesystems. A plain directory bind-mount must work everywhere.
- The CLI should present a consistent interface regardless of the underlying filesystem.
- The orchestrator manages state and timing; filesystem tools execute operations.

## Decision

Volumes declare a driver. Podmander provides a consistent interface while behavior varies by driver:

| Driver | Availability | Snapshot | Send/Receive |
|--------|-------------|----------|--------------|
| `directory` | Any filesystem | No | No |
| `btrfs` | Mainline Linux kernel | Yes | Yes |
| `zfs` | Requires OpenZFS | Yes | Yes |

The CLI abstracts driver differences — `podmander volume rollback` works identically regardless of driver. Under the hood, the implementation differs:

- **ZFS**: native `zfs rollback` command.
- **BTRFS**: stop services, rename current subvolume, create snapshot from target, restart.

The driver is specified per volume in the stack TOML and determines what operations are available.

## Consequences

### Positive

- Consistent CLI regardless of filesystem — operators learn one set of commands.
- Progressive capability — start with `directory` (works everywhere), upgrade to `btrfs` or `zfs` for snapshot support without changing service definitions.
- Driver abstraction isolates filesystem-specific logic — adding a new driver does not affect the rest of the codebase.
- Follows the "generate, don't execute" philosophy — Podmander issues filesystem commands via SSH, the filesystem tools execute.

### Negative

- `directory` driver has no snapshot support — operators using it lose rollback-to-data-state capability.
- Rollback semantics differ subtly between drivers (ZFS is atomic, BTRFS requires a stop-rename-snapshot-restart sequence). The abstraction hides this but operators may notice the downtime difference.
- Three drivers to test and maintain.

### Neutral

- Snapshot-capable volumes require rootful nodes (see [ADR-0012](0012-rootless-containers-rootful-agent.md)) since BTRFS/ZFS operations need elevated privileges.
- Mixed drivers per service are allowed (some volumes on BTRFS, others on directory).

## Alternatives Considered

### BTRFS/ZFS only (no directory driver)

- Pros: Simpler — all volumes have snapshot capability. No "degraded mode" to handle.
- Cons: Requires all nodes to have a copy-on-write filesystem. Excludes deployments on cloud VMs with ext4 root filesystems, Raspberry Pis with default setups, and other environments where BTRFS/ZFS is not practical.
- Why rejected: Excluding common deployment environments contradicts the "less than Kubernetes" positioning.

### Docker/Podman volume plugins

- Pros: Standard container ecosystem approach. Plugin API is well-defined.
- Cons: Volume plugins are designed for container runtimes, not orchestrators. Podmander generates Quadlet files — it does not directly manage Podman volumes at runtime. Plugin lifecycle management adds complexity.
- Why rejected: Podmander operates at the Quadlet/systemd layer, not the container runtime layer. Filesystem operations via SSH are simpler and more debuggable.

## References

- [ADR-0026](0026-btrfs-default-zfs-optional.md) — BTRFS as recommended default, ZFS as optional
- [ADR-0027](0027-snapshots-linked-to-versions.md) — Snapshots linked to service versions
- [ADR-0012](0012-rootless-containers-rootful-agent.md) — Rootless containers with rootful agent (snapshot operations need rootful)
