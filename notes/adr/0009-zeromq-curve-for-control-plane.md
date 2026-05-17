# ADR-0009: ZeroMQ with CURVE Encryption for Control Plane

**Status**: Accepted
**Date**: 2026-04-12

## Context

The controller needs a communication channel for commands, status reports, and heartbeats with agents across multiple nodes. This channel must be persistent (agents stay connected), support async messaging patterns (commands flow controller→agent, heartbeats flow agent→controller), and be encrypted end-to-end.

Key forces:

- Agents must maintain long-lived connections with automatic reconnection on network interruptions.
- The controller communicates with many agents simultaneously — the protocol must support multiplexed connections.
- Encryption must be built into the protocol, not bolted on (no reliance on network-level VPNs for confidentiality).
- Agent enrollment must be possible with a simple shared token — no certificate authority infrastructure.
- For future HA, multiple controller instances should be able to share credentials so agents can reconnect without re-enrollment.

## Decision

We will use ZeroMQ with CURVE encryption for the control plane.

The controller binds a ROUTER socket; agents connect with DEALER sockets. This gives the controller addressable connections to each agent while agents see a simple request-reply channel.

CURVE encryption (libsodium-based, NaCl) secures all traffic. The controller generates a CURVE keypair on cluster initialization. The public key is embedded in the join token (`PTKN-<z85-controller-pubkey>-<hex-enrollment-secret>`), which agents use to establish encrypted connections. Each agent generates its own CURVE keypair on startup.

Agents send heartbeats at a configurable interval (default 30 seconds). The controller marks an agent as unresponsive after 2x the interval with no heartbeat, and disconnected after 3 consecutive missed heartbeats.

For HA, all controller instances share the same CURVE keypair, so agents reconnect to a floating endpoint without needing re-enrollment.

## Consequences

### Positive

- Persistent connections with automatic reconnection — agents handle transient network failures transparently.
- ROUTER/DEALER pattern allows the controller to address individual agents while supporting broadcast-style status collection.
- CURVE encryption provides mutual authentication and confidentiality without a certificate authority.
- Join token is a single string — simple to distribute during node bootstrap.
- Shared keypair design supports future HA without agent-side protocol changes.

### Negative

- ZeroMQ requires Ada bindings or FFI wrappers (C library with Ada thin binding).
- CURVE uses a custom key format (Z85-encoded) — not interoperable with standard TLS/PKI infrastructure.
- No built-in message persistence — if the controller is down, messages are lost (acceptable because the supervisor loop reconciles on reconnection).
- Debugging encrypted ZeroMQ traffic requires application-level logging; standard network tools cannot inspect it.

### Neutral

- Join tokens can be rotated without affecting already-enrolled nodes — rotation only affects future enrollments.

## Alternatives Considered

### gRPC with mutual TLS

- Pros: Industry-standard, rich tooling, streaming support, well-understood PKI model.
- Cons: Requires a certificate authority or certificate distribution mechanism. More complex connection management for persistent agent connections. No Ada gRPC library available.
- Why rejected: Certificate management adds operational complexity for the target audience. No Ada implementation.

### Plain SSH (single protocol for all communication)

- Pros: Single protocol for commands and file transfers. SSH is widely understood and available.
- Cons: SSH is connection-oriented without built-in async messaging. Implementing command/status/heartbeat patterns over SSH would require a custom protocol layer. No persistent connection with automatic reconnection. File transfers over SSH would require persistent key management and connection lifecycle handling.
- Why rejected: Poor fit for async command-and-status messaging patterns. Would require building a bespoke protocol on top of SSH, negating the simplicity benefit. ZMQ now handles file payloads as well (see [ADR-0036](0036-zeromq-unified-transport.md)), eliminating the need for SSH as a runtime transport entirely.

### MQTT

- Pros: Designed for IoT/agent communication, lightweight, supports persistent connections and QoS levels.
- Cons: Requires a broker (additional infrastructure). Pub/sub model less natural for addressed commands to specific agents. No built-in encryption (requires TLS wrapper).
- Why rejected: External broker dependency is unacceptable for the target audience. The controller should be the only infrastructure component.

## References

- [ADR-0010](0010-ssh-for-data-plane.md) — SSH for data plane (the other half of the hybrid model)
- [ADR-0001](0001-controller-agent-topology.md) — Controller-agent topology (defines the communication pattern)
