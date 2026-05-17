# ADR-0032: SSH-Based Node Bootstrap with Role-Based Installation

**Status**: Abandoned
**Date**: 2026-04-12

## Context

Adding a node to the Podmander fleet requires installing software (Podman, the agent, role-specific components), configuring users and services, and connecting the agent to the controller. The bootstrap mechanism determines how this happens.

Key forces:

- The only prerequisite on a new node should be an SSH server and the controller's public key. Everything else should be automated.
- Different node roles need different software (ingress nodes need Caddy, storage nodes need ZFS utilities, DNS nodes need CoreDNS).
- The agent always runs as root (see [ADR-0012](0012-rootless-containers-rootful-agent.md)). "Rootless" refers to the container runtime — a separate unprivileged user runs containers.
- The bootstrap must support multiple Linux distributions (apt, dnf, pacman).

## Decision

The controller bootstraps nodes by generating and executing a setup script over SSH.

When the operator runs `podctl node add <name> --host=<addr> --role=<role>`:

1. Controller generates a `bootstrap.sh` script dynamically for the node, based on its role and configuration.
2. Controller SCPs the script to the node.
3. Controller executes the script via SSH.
4. The script detects the package manager, installs components, creates users, and starts the agent.
5. The agent connects to the controller and enrolls via the join token.

Role-based installation:

| Component | All nodes | Ingress | DNS | Storage |
|-----------|-----------|---------|-----|---------|
| Podman | Yes | Yes | Yes | Yes |
| Agent | Yes | Yes | Yes | Yes |
| Caddy | - | Yes | - | - |
| CoreDNS | - | - | Yes | - |
| Restic | - | - | - | Yes |
| ZFS utils | - | - | - | Yes |

For rootless nodes, the script also creates the container user account, configures `loginctl enable-linger`, and sets up subuid/subgid mappings.

## Consequences

### Positive

- Minimal prerequisites — SSH server and an authorized key are all that is needed on a fresh node.
- Role-based installation ensures each node gets exactly the software it needs.
- Dynamic script generation handles distribution differences (apt vs dnf vs pacman) transparently.
- Single command (`podctl node add`) for the operator — no manual node preparation beyond SSH access.
- Rerunnable — `podctl node bootstrap <name>` re-executes the script for recovery.

### Negative

- SSH with root/sudo access is required during bootstrap — a broad privilege, though temporary.
- Package manager detection may fail on unusual distributions.
- Agent binary distribution is an open concern (embedded in controller vs external registry).
- Bootstrap script is not signed — a future extension for security-conscious deployments.
- No support for non-systemd init systems (OpenRC, runit) — systemd is assumed.

### Neutral

- After bootstrap, the controller's SSH key is added to root's `authorized_keys` for ongoing file transfers.
- The bootstrap does not reverse on node removal — Podman, Caddy, etc. remain installed. A `--purge` flag is available for cleanup.

## Alternatives Considered

### Manual node preparation (operator installs everything)

- Pros: No privileged script execution. Operator has full control.
- Cons: Error-prone, tedious, does not scale. Every distribution requires different steps. Easy to miss a step (lingering, subuid, systemd unit).
- Why rejected: The target audience needs automation. Manual preparation is acceptable for advanced users but should not be the default.

### Configuration management (Ansible, Puppet, Chef)

- Pros: Mature, idempotent, well-tested for node provisioning.
- Cons: External dependency — operators must install and learn a configuration management tool. Adds a tool to the stack that is only used for one operation (bootstrap).
- Why rejected: Disproportionate dependency for a one-time operation per node. A generated shell script achieves the same result without external tools.

### Container-based agent (no host installation)

- Pros: Agent runs in a container — no host-level package installation beyond the container runtime.
- Cons: The agent needs host-level access for WireGuard, systemd, and file placement. Running a container with enough host access to manage systemd and WireGuard is effectively running as root with extra indirection.
- Why rejected: The agent's responsibilities require host-level access. Containerizing it adds complexity without isolation benefit.

## References

- [ADR-0010](0010-ssh-for-data-plane.md) — SSH for data plane (same SSH infrastructure used for bootstrap)
- [ADR-0012](0012-rootless-containers-rootful-agent.md) — Rootless containers with rootful agent
- [ADR-0001](0001-controller-agent-topology.md) — Controller-agent topology (agent enrollment after bootstrap)
