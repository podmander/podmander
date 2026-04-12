# ADR-0011: Podman with Quadlet for Container Execution

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander generates configuration that other tools execute (the core design philosophy). For container execution, we need a runtime and a mechanism to express container declarations that integrates with systemd, since services are managed as systemd units (see [ADR-0007](0007-services-as-systemd-units.md)).

Key forces:

- The runtime must support rootless containers for the default security posture (see [ADR-0012](0012-rootless-containers-rootful-agent.md)).
- Container declarations should be files that Podmander generates and agents place on disk — not imperative commands that must be re-issued after reboot.
- The runtime must integrate with systemd for lifecycle management, restart policies, and dependency ordering.
- Podmander generates config for other tools (Caddy, CoreDNS, Restic). The container runtime should follow the same pattern.

## Decision

We will use Podman as the container runtime and Quadlet as the declaration format.

Quadlet files (`.container`, `.volume`, `.network`) are declarative specifications that systemd's Quadlet generator translates into native systemd units. Podmander generates these files; systemd and Podman execute them.

This aligns with the core pattern: Podmander generates configuration, specialized tools execute it.

## Consequences

### Positive

- Quadlet files are declarative — Podmander generates files, not imperative commands. Consistent with the config-generation philosophy.
- Native systemd integration via the Quadlet generator. No custom service files needed.
- Rootless Podman support via user namespaces — containers run without root privileges by default.
- Daemonless architecture — Podman does not require a long-running daemon, reducing the system's failure surface.
- Containers survive agent restart because they are systemd units (see [ADR-0007](0007-services-as-systemd-units.md)).
- TOML-based Quadlet format aligns with Podmander's TOML configuration (see [ADR-0004](0004-custom-toml-over-compose-yaml.md)).

### Negative

- Quadlet format constrains expressiveness — some advanced container options may require workarounds or `PodmanArgs=` escape hatches.
- Podman has a smaller ecosystem than Docker — fewer third-party integrations, though OCI image compatibility means most images work unchanged.
- Some operators may be unfamiliar with Quadlet syntax, though they rarely need to interact with it directly.

### Neutral

- OCI image compatibility means Docker images work without modification.
- Podman CLI is largely compatible with Docker CLI, easing migration for operators familiar with Docker.

## Alternatives Considered

### Docker with docker-compose

- Pros: Largest ecosystem, most widely known, extensive documentation.
- Cons: Requires a root daemon (dockerd) — a long-running privileged process and single point of failure on each node. Rootless mode is less mature. No native Quadlet equivalent — would need custom systemd unit files or Docker's own restart policies.
- Why rejected: Daemon requirement conflicts with the principle that agent crash should not affect workloads. Docker's rootless mode is less mature than Podman's.

### Docker with systemd unit files (no compose)

- Pros: Docker as runtime, systemd for lifecycle, no daemon dependency for running containers (systemd manages them).
- Cons: Requires hand-crafting systemd unit files with `ExecStart=docker run ...`. No declarative format equivalent to Quadlet. Docker still needs its daemon for image pulls and container creation.
- Why rejected: Quadlet provides a cleaner declarative-to-systemd pipeline. Docker daemon is still required even if systemd manages container lifecycle.

### containerd (direct, no Docker/Podman)

- Pros: Lightweight, used by Kubernetes as CRI runtime, no daemon overhead.
- Cons: Low-level API — no user-facing CLI, no rootless support, no Quadlet equivalent. Would require Podmander to implement significant container management logic.
- Why rejected: Too low-level. Podmander would need to reimplement functionality that Podman and Quadlet provide.

## References

- [ADR-0007](0007-services-as-systemd-units.md) — Services as systemd units
- [ADR-0012](0012-rootless-containers-rootful-agent.md) — Rootless containers with rootful agent
- [ADR-0004](0004-custom-toml-over-compose-yaml.md) — Custom TOML schema
