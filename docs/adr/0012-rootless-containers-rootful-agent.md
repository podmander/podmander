# ADR-0012: Rootless Containers with Rootful Agent

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander agents perform two categories of operations with different privilege requirements:

1. **System-level operations** — WireGuard management, systemd unit installation, file placement to system directories, infrastructure configuration (CoreDNS, Caddy, Restic).
2. **Container execution** — running application workloads.

These have conflicting security properties: system operations need root, while containers should run with minimal privileges to limit blast radius.

Key forces:

- Container compromise should not grant root access to the host.
- The agent must manage WireGuard interfaces, install systemd units, and place files in system directories — operations that require root.
- Different nodes have different needs: application nodes benefit from rootless containers, while ingress nodes need privileged ports (80/443) and storage nodes need direct filesystem access (ZFS/BTRFS).
- Podman's rootless mode is mature and production-ready.

## Decision

The agent runs as root on all nodes. "Rootless" refers to the container runtime, not the agent.

Containers run under an unprivileged user via Podman user namespaces by default (rootless mode). Nodes can be individually marked as rootful when needed.

| Mode | Agent runs as | Containers run as | Use case |
|------|---------------|-------------------|----------|
| Rootless | root | Unprivileged user | Application nodes (default) |
| Rootful | root | root | Ingress (ports 80/443), storage (ZFS/BTRFS) |

Typical setup: application nodes are rootless, ingress and storage nodes are rootful.

## Consequences

### Positive

- Defense in depth — container compromise does not grant root access on rootless nodes.
- Agent has the privileges it needs for system-level operations without workarounds.
- Per-node mode selection allows the right privilege level for each role without fleet-wide compromise.
- Podman's rootless mode is mature and handles user namespaces, cgroup delegation, and networking transparently.

### Negative

- Rootless containers have limitations: Quadlets go in `~/.config/containers/systemd/` (not system-level), require `loginctl enable-linger` for persistence, port binding below 1024 needs extra configuration, and UID mapping adds complexity for volume mounts.
- The agent running as root is a broad privilege — a compromised agent binary has full system access. Mitigation: agent binary integrity verification, minimal attack surface, systemd hardening options.
- Two modes (rootless/rootful) increase testing surface.

### Neutral

- A single node can run both modes if needed (different SSH users, different Podman instances), though this is an unusual configuration.
- The agent running as root simplifies the agent's implementation — no privilege escalation needed for any operation.

## Alternatives Considered

### Rootless agent with privilege escalation

- Pros: Agent runs as unprivileged user by default, uses sudo/polkit for specific operations.
- Cons: Complex privilege escalation rules. Every system operation (WireGuard, systemd, file placement) needs its own escalation path. Error-prone configuration. Debugging privilege failures adds operational burden.
- Why rejected: The agent is a trusted component installed during node bootstrap. Running it as root is simpler and more reliable than managing fine-grained privilege escalation for every system operation.

### Rootful everything

- Pros: Simplest — no user namespace complexity, no rootless limitations, no mode selection.
- Cons: Container compromise grants root access to the host. Violates the principle of least privilege. No security differentiation for application workloads.
- Why rejected: Unacceptable security posture for the default configuration. Rootless containers are a meaningful security boundary.

### Container-level privilege per service (not per node)

- Pros: Maximum flexibility — each service chooses its privilege level independently.
- Cons: Requires running both rootless and rootful Podman instances on the same node simultaneously, with separate systemd user sessions, separate Quadlet directories, and separate state. Significantly more complex than per-node mode selection.
- Why rejected: Per-node mode covers real-world use cases (ingress nodes are rootful, app nodes are rootless). Per-service granularity adds complexity without clear benefit — services needing root typically co-locate on dedicated nodes anyway.

## References

- [ADR-0011](0011-podman-quadlet-for-containers.md) — Podman with Quadlet for container execution
- [ADR-0007](0007-services-as-systemd-units.md) — Services as systemd units
