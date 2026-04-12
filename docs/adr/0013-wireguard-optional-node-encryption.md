# ADR-0013: WireGuard as Optional Node-Level Encryption

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander targets mixed networking environments. Some deployments have private networks (VLANs, VPCs) where inter-node traffic is already isolated. Others have nodes communicating over public IPs or cross-datacenter links where traffic traverses untrusted networks.

Key forces:

- Deployments on private networks should not pay the overhead of an encryption layer they do not need.
- Deployments on public networks need encrypted inter-node traffic without requiring operators to set up a separate VPN.
- Containers use normal Podman networking (host port bindings). A container overlay network (macvlan on WireGuard, per-node subnets) was considered and rejected — it conflicts with rootless Podman and adds unnecessary complexity.
- The encryption layer must be transparent to containers — services communicate via hostname and port, resolved through CoreDNS.

## Decision

WireGuard is an optional node-level transport encryption layer, not a container overlay network.

When enabled, Podmander generates WireGuard configurations to create a full mesh between all nodes. Each node runs WireGuard as a systemd service (`wg-quick@wg0`). Containers are unaware of WireGuard — they communicate via host port mappings routed through WireGuard tunnels. CoreDNS resolves service names to WireGuard IPs when the mesh is enabled, to host IPs when it is not (see [ADR-0016](0016-coredns-daemonset.md)).

Deployments with private networks skip WireGuard entirely — no configuration, no overhead, no WireGuard dependency on nodes.

## Consequences

### Positive

- No overhead for private-network deployments — WireGuard is purely opt-in.
- Node-level encryption is transparent to containers — no application changes, no container networking complexity.
- Avoids rootless/macvlan conflicts that a container overlay would introduce.
- Simpler than a full overlay network — one IP per node, no per-container addressing.
- CoreDNS integration means service discovery works identically regardless of whether WireGuard is enabled.

### Negative

- WireGuard must be installed on nodes where it is enabled — the kernel module (`wireguard`, Linux 5.6+) is assumed.
- Full mesh topology scales to approximately 20 nodes before config churn becomes painful. Beyond that, hub-and-spoke topology is needed (future extension).
- NAT-to-NAT (both peers behind NAT with no port forwarding) is not supported — operators in this situation should use Tailscale or similar.
- Single-thread-per-tunnel limits throughput (typically 1–10 Gbps on modern x86). This is sufficient for most inter-service traffic but may bottleneck backup or large-data workloads.

### Neutral

- WireGuard setup happens post-enrollment — it does not complicate the agent enrollment flow.
- Performance is adequate for the target audience (web/database workloads). High-bandwidth flows (backups) can bypass WireGuard if needed.

## Alternatives Considered

### Container overlay network (macvlan on WireGuard)

- Pros: Per-container IPs, direct container-to-container routing without host port mappings.
- Cons: macvlan on WireGuard does not work cleanly. Conflicts with rootless Podman's networking model. Per-node subnets (/24) waste address space and add routing complexity. Fundamentally solves a different problem (routable container IPs) than what is needed (encrypted transport).
- Why rejected: The actual need is encrypted transport between nodes, not routable container IPs. The overlay approach adds complexity without solving the right problem.

### Always-on WireGuard (mandatory)

- Pros: Simpler configuration — no conditional behavior. Encrypted by default.
- Cons: Unnecessary overhead for private-network deployments. Requires WireGuard on every node even when the network is already trusted. Adds a mandatory dependency.
- Why rejected: Many deployments are on private networks where WireGuard adds overhead without benefit.

### Tailscale / Nebula (managed mesh)

- Pros: Easier NAT traversal (including NAT-to-NAT), managed key distribution, no kernel module required (userspace mode available).
- Cons: External dependency — requires a coordination server (Tailscale's, or self-hosted Headscale/Nebula lighthouse). Podmander would depend on a third-party service for a core networking function. Userspace mode has lower performance.
- Why rejected: External dependency for core networking is unacceptable. For the majority of deployments (at least one peer with a public IP or port forwarding), WireGuard's NAT traversal is sufficient. Tailscale is recommended as documentation guidance for NAT-to-NAT edge cases.

## References

- [ADR-0014](0014-wireguard-per-node-slash32-ips.md) — Per-node /32 WireGuard IPs
- [ADR-0015](0015-node-local-wireguard-keypairs.md) — Node-local keypair generation
- [ADR-0016](0016-coredns-daemonset.md) — CoreDNS resolves to WireGuard IPs when enabled
- [ADR-0012](0012-rootless-containers-rootful-agent.md) — Rootless containers (WireGuard avoids overlay conflicts)
