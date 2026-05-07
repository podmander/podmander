# ADR-0014: Per-Node /32 WireGuard IPs from Configurable Pool

**Status**: Accepted
**Date**: 2026-04-12

## Context

When WireGuard is enabled (see [ADR-0013](0013-wireguard-optional-node-encryption.md)), each node needs a WireGuard IP address for the mesh. The addressing scheme affects routing complexity, address space consumption, and how the mesh scales.

Key forces:

- WireGuard is node-level encryption, not a container overlay. Containers do not receive WireGuard IPs.
- The addressing scheme should be simple to manage and reason about.
- The default address range must avoid conflicts with common private network ranges.
- The pool must be large enough for the target deployment size while remaining configurable for environments with specific constraints.

## Decision

Each node receives a single `/32` WireGuard IP from a configurable pool (default `10.99.0.0/16`). The controller allocates addresses sequentially during post-enrollment networking setup.

Example: Node A gets `10.99.0.1/32`, Node B gets `10.99.0.2/32`, Node C gets `10.99.0.3/32`.

The default range `10.99.0.0/16` provides 65,534 addresses — well above the target deployment size — and avoids common conflicts (`10.0.0.0/8` subnets, `172.16.0.0/12`, `192.168.0.0/16` ranges that operators commonly use).

## Consequences

### Positive

- Simple addressing — one IP per node, no subnets to manage, no routing tables to maintain.
- Default range avoids common private network conflicts.
- 65K addresses is more than sufficient for the target scale (up to ~20 nodes for full mesh).
- Configurable pool accommodates environments with specific network constraints.

### Negative

- `/32` per node means no local subnet — all inter-node traffic requires explicit peer routes. This is the normal WireGuard model but differs from traditional subnet-based networking.
- If the default range conflicts with an operator's existing network, they must configure an alternative.

### Neutral

- Address allocation is managed by the controller and persisted in SQLite. Node removal frees the address for future reuse.

## Alternatives Considered

### Per-node /24 subnets (container overlay style)

- Pros: Each node gets a subnet for containers, enabling direct container-to-container routing without host port mappings.
- Cons: Consumes 256 addresses per node. Requires routing rules for cross-node traffic. Designed for container overlay networks, which was rejected in [ADR-0013](0013-wireguard-optional-node-encryption.md).
- Why rejected: WireGuard is node-level transport, not a container overlay. Per-node subnets solve a problem Podmander does not have.

### Single shared /24 for all nodes

- Pros: Simple, familiar subnet model.
- Cons: Limited to 254 nodes. More complex WireGuard configuration (allowed IPs must specify the full subnet). Broadcast concerns in larger deployments.
- Why rejected: `/32` per node is simpler for WireGuard point-to-point peering and does not impose artificial node limits.

## References

- [ADR-0013](0013-wireguard-optional-node-encryption.md) — WireGuard as optional node-level encryption
- [ADR-0015](0015-node-local-wireguard-keypairs.md) — Node-local keypair generation
