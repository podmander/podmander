# WireGuard Node-to-Node Encryption Requirements

**Version:** 1.1
**Status:** Draft
**Date:** 2026-04-09

## Problem Frame

Podmander targets mixed networking environments: some deployments have private
VLANs or VPCs where nodes can already reach each other securely, others have
only public IPs where inter-node traffic crosses the internet unencrypted.
Containers communicate with services on other nodes via hostname and port
(resolved through CoreDNS), so the traffic between nodes must be encrypted in
public-IP deployments.

The solution must be optional — operators with private networks skip it entirely
— and must not interfere with Podmander's rootless-by-default container model.
WireGuard operates at the node level as an encrypted transport layer, not as a
container overlay network.

## Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R1 | Podmander generates WireGuard peer configurations for a full mesh between enrolled nodes | Must Have | Controller knows all node endpoints from enrollment |
| R2 | Each node generates its own WireGuard keypair locally; only public keys are exchanged via the controller | Must Have | Private keys never leave the node |
| R3 | Each node receives a single WireGuard IP address (e.g., `10.99.0.1/32`), not a subnet | Must Have | Node-level transport, not container overlay |
| R4 | WireGuard is optional — deployments with private networks skip it; CoreDNS resolves to host IPs instead of WireGuard IPs | Must Have | Operator chooses via cluster config |
| R5 | When WireGuard is enabled, CoreDNS zone files resolve service names to WireGuard IPs of the nodes hosting those services | Must Have | Seamless integration with service discovery |
| R6 | Podmander configures MTU on the WireGuard interface to avoid fragmentation (default: 1420 for IPv4, configurable) | Must Have | Silent packet drops are unacceptable |
| R7 | PersistentKeepalive is configured for peers behind NAT (default: 25 seconds, configurable) | Must Have | Required for NAT traversal in common deployments |
| R8 | When a node is added or removed, Podmander regenerates and distributes updated peer configs to all affected nodes | Must Have | Mesh must stay consistent |
| R9 | WireGuard service runs as a system-level systemd unit (`wg-quick@wg0`), managed by the agent which runs as root on all nodes | Must Have | Agent runs as root; "rootless" refers to containers via Podman user namespaces, not the agent |
| R10 | Podmander detects WireGuard connectivity failures between nodes and reports them via the existing monitoring/alerting path | Should Have | Operators need visibility into tunnel health |
| R11 | Peer config updates are applied without dropping existing connections where possible (`wg syncconf` over full restart) | Should Have | Minimizes disruption during node add/remove |
| R12 | Support for specifying a WireGuard endpoint address distinct from the SSH host address (e.g., public IP for WireGuard, private IP for SSH) | Should Have | Common in mixed-network setups |
| R13 | WireGuard key rotation initiated by operator command, with rolling update across nodes | Nice to Have | Security hygiene, but not MVP-critical |

## Success Criteria

- A cluster with WireGuard enabled passes traffic between containers on different nodes through the encrypted tunnel, verified by packet capture on the WireGuard interface.
- A cluster without WireGuard enabled works identically using host IPs — no WireGuard dependencies in the code path.
- Adding or removing a node updates all peer configs within one reconciliation cycle without dropping existing tunnels.
- MTU is correctly configured such that TCP connections with large payloads (e.g., TLS, file transfers) do not hang or time out.
- Nodes behind simple NAT (port-forwarded, not NAT-to-NAT) maintain stable tunnels via PersistentKeepalive.

## Scope Boundaries

**In scope:**
- WireGuard config generation and distribution to nodes
- WireGuard IP address allocation (one IP per node from a configurable pool)
- MTU and PersistentKeepalive configuration
- Integration with CoreDNS (resolve to WireGuard IPs when enabled)
- Peer lifecycle management (add/remove nodes)
- Connectivity monitoring

**Out of scope:**
- NAT-to-NAT hole punching (both peers behind NAT with no port forwarding — document as a known limitation, recommend Tailscale for these environments)
- Container-level overlay networking (macvlan, VXLAN, etc.)
- WireGuard installation on nodes (prerequisite, like SSH)
- Hub-and-spoke topology (future extension for larger clusters)
- Stack-level network isolation (future extension)

## Key Decisions

| Decision | Chosen | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| WireGuard as node transport, not container overlay | Node-level encryption | Avoids macvlan/rootless conflicts; actual need is encrypted transport, not routable container IPs | Container overlay with macvlan (rejected: doesn't work with rootless Podman, complex routing issues) |
| Key generation locality | Node generates own keypair | Security: private keys never leave the node; aligns with WireGuard's security model | Controller generates and distributes keys (rejected: single point of compromise, violates least privilege) |
| Address allocation | One IP per node (`/32`) | No container subnet needed; simpler, conserves address space | `/24` per node (rejected: wasteful, implies container overlay model) |
| WireGuard optionality | Opt-in via cluster config | Private network deployments shouldn't carry WireGuard overhead or complexity | Always-on (rejected: unnecessary for VLAN/VPC environments) |
| NAT-to-NAT support | Out of scope | Requires UDP hole punching or relay servers; complexity exceeds value for MVP | Implement hole punching (rejected: significant complexity, Tailscale exists) |
| Config application method | `wg syncconf` preferred over restart | Avoids dropping existing connections during peer updates | Full `wg-quick down/up` (rejected: drops all connections) |
| Agent privilege model | Agent always runs as root | Simplifies WireGuard management, ZFS operations, and system-level config. "Rootless" means rootless containers via Podman user namespaces, not an unprivileged agent. | Unprivileged agent with sudoers (rejected: more setup complexity, same effective privilege) |
| WireGuard IP range | `10.99.0.0/16` (configurable) | Avoids common `10.0.x.x` and `10.1.x.x` ranges; 65,534 node IPs is far beyond target scale | `100.64.0.0/16` CGNAT range (rejected: surprising), `172.30.0.0/16` (rejected: may conflict with operator networks) |
| WireGuard key exchange timing | Post-enrollment step, separate from join token | Keeps enrollment simple; decouples WireGuard from core join flow; join token stays `PTKN-<curve-pubkey>-<enrollment-secret>` | During enrollment (rejected: couples networking to core enrollment flow) |
| Missing WireGuard handling | Fail the networking configuration step | Enrollment succeeds but WireGuard setup fails with clear error. Node is enrolled but has no mesh connectivity. Operator installs WireGuard and retries. | Warn and skip (rejected: risks unencrypted traffic going unnoticed) |

## Resolved Questions

| # | Question | Resolution |
|---|----------|------------|
| Q1 | Agent privilege for WireGuard operations | Agent always runs as root. "Rootless" refers to containers, not the agent. |
| Q2 | WireGuard IP allocation range | `10.99.0.0/16` default, configurable. |
| Q3 | Key exchange timing | Post-enrollment step, separate from join token. |
| Q4 | Missing WireGuard on node | Fail the networking config step. Enrollment succeeds, WireGuard setup fails with clear error. |

## Related ADRs

These requirements were incorporated into the following architecture decisions:

- [ADR-0012](../adr/0012-rootless-containers-rootful-agent.md) — Agent runs as root; rootless applies to containers
- [ADR-0013](../adr/0013-wireguard-optional-node-encryption.md) — WireGuard as optional node-level encryption
- [ADR-0014](../adr/0014-wireguard-per-node-slash32-ips.md) — Per-node /32 WireGuard IPs
- [ADR-0015](../adr/0015-node-local-wireguard-keypairs.md) — Node-local keypair generation
