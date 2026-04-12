# ADR-0015: Node-Local WireGuard Keypair Generation

**Status**: Accepted
**Date**: 2026-04-12

## Context

Each node in the WireGuard mesh (see [ADR-0013](0013-wireguard-optional-node-encryption.md)) needs a cryptographic keypair. The private key must be protected — if compromised, all traffic to and from that node can be decrypted. The question is where keypairs are generated and how private keys are handled.

Key forces:

- WireGuard private keys should never traverse a network — the WireGuard protocol is designed around this principle.
- The controller needs each node's public key to distribute peer configurations to other nodes.
- The ZeroMQ channel between controller and agent is CURVE-encrypted (see [ADR-0009](0009-zeromq-curve-for-control-plane.md)), so public key transmission is confidential.
- Key management should be automatic — operators should not need to manually generate, copy, or rotate keys.

## Decision

Each node generates its own WireGuard keypair locally. Private keys never leave the node.

During post-enrollment networking setup:

1. The agent generates a WireGuard keypair using `wg genkey` / `wg pubkey`.
2. The agent sends only the public key to the controller via the CURVE-encrypted ZeroMQ channel.
3. The controller stores the public key and distributes it (along with the node's endpoint and WireGuard IP) to all other nodes in the mesh.
4. The private key stays on the node in `/etc/wireguard/wg0.conf` (mode `0600`, root-owned).

## Consequences

### Positive

- Private keys never traverse the network — aligns with WireGuard's security model.
- Compromise of the controller does not expose node private keys (only public keys, which are not sensitive).
- Aligns with WireGuard's design intent — the protocol assumes local keypair generation.
- Fully automatic — no operator key management required.

### Negative

- Key rotation requires agent-side coordination — the controller cannot unilaterally rotate a node's keypair. Key rotation is a future extension.
- If a node's private key is compromised, only that node is affected (but all traffic to/from that node is exposed until rotation).

### Neutral

- The controller stores only public keys in SQLite — the database does not contain sensitive key material for WireGuard.
- Peer config updates (adding/removing nodes) use `wg syncconf` to avoid dropping existing connections during reconfiguration.

## Alternatives Considered

### Controller generates keypairs and distributes them

- Pros: Centralized key management, easier rotation (controller owns all keys), simpler agent logic.
- Cons: Private keys traverse the network (even over CURVE-encrypted ZeroMQ, this violates WireGuard's security model). Controller compromise exposes all node private keys. Violates principle of least privilege — the controller does not need private keys.
- Why rejected: Unnecessary exposure of private key material. The WireGuard ecosystem assumes local generation, and the security benefits of keeping private keys node-local are clear.

### Pre-shared keys distributed via SSH

- Pros: Out-of-band key distribution, no ZeroMQ dependency for key exchange.
- Cons: Requires writing private keys to the SSH transfer pipeline. Additional complexity for key distribution during bootstrap. Still violates the local-generation principle.
- Why rejected: Same fundamental issue — private keys leave the node. The CURVE-encrypted ZeroMQ channel is sufficient for public key transmission.

## References

- [ADR-0013](0013-wireguard-optional-node-encryption.md) — WireGuard as optional node-level encryption
- [ADR-0014](0014-wireguard-per-node-slash32-ips.md) — Per-node /32 WireGuard IPs
- [ADR-0009](0009-zeromq-curve-for-control-plane.md) — ZeroMQ CURVE encryption (used for public key transmission)
