# ADR-0036: ZeroMQ as Sole Runtime Transport Between Controller and Agent

**Status**: Accepted
**Date**: 2026-05-17
**Supersedes**: [ADR-0010](0010-ssh-for-data-plane.md)

## Context

ADR-0009 established ZeroMQ with CURVE encryption as the control plane transport for commands, status, and heartbeats. ADR-0010 prescribed SSH/SCP as a separate data plane for file transfers (Quadlets, Caddyfiles, zone files, Restic configs).

The initial implementation (PR #64) transferred Quadlet content inline as a string payload in a ZeroMQ `Deployment_Command` message. This worked without any SSH infrastructure. Reviewing this against ADR-0010 raised the question: is SSH actually needed?

The files Podmander transfers between controller and agent are small configuration files — Quadlets under 1 KB, Caddyfiles and zone files under 10 KB. Podman pulls container images from registries; Podmander never transfers images. ZeroMQ handles messages up to ~2 GB, making these payloads well within its capacity.

ZeroMQ with CURVE already provides:
- **Integrity**: CURVE uses NaCl authenticated encryption. Any corruption or tampering causes a decryption failure — the message either arrives intact or doesn't arrive at all.
- **Atomicity**: ZMQ messages are atomic. There is no partial delivery — the receiver gets the complete message or nothing.
- **Encryption**: CURVE provides mutual authentication and confidentiality without a certificate authority.

Node bootstrap (installing the agent, configuring the join token) is an operational concern handled by the operator, not an architectural decision the software prescribes. The software provides pre-flight checks to verify prerequisites at startup.

## Decision

ZeroMQ is the sole runtime transport between controller and agent. There is no separate data plane protocol. Control plane and data plane remain distinct conceptual layers sharing one transport.

All file payloads — Quadlets, Caddyfiles, CoreDNS zone files, Restic configurations, and any future file types — travel over ZeroMQ.

All protocol messages use JSON as their payload format. Each ZMQ message is a single JSON frame: a flat object with a `kind` field for dispatch and type-specific fields for the payload. Example:

```json
{"kind": "deployment", "service_name": "webapp", "quadlet": "[Unit]\n..."}
```

This replaces the previous positional-frame encoding. All existing message types (registration, heartbeat, deployment, deployment_ack, status, status_ack) migrate to JSON. No mixed protocol — positional frames are removed entirely.

Agent-side file writes use atomic replacement: content is written to a temporary file in the target directory, then renamed to the final path. This prevents partial files from being activated by systemd.

Node bootstrap is an operational concern, not a software architectural decision. The software provides pre-flight checks at startup; the operator is responsible for meeting the prerequisites.

## Consequences

### Positive

- Single encrypted channel to configure, monitor, and debug. No SSH key distribution, no ControlMaster lifecycle, no bastion configuration for a second protocol.
- ZMQ CURVE join tokens already solve enrollment. No additional key management for file transfer.
- JSON payloads are self-describing and extensible. Adding new message types or fields does not require changing the frame-order protocol.
- Atomic file writes prevent partial-file activation without adding a staging + checksum protocol layer.
- Fewer dependencies — no SSH client library needed in the controller or agent.

### Negative

- JSON parsing adds a dependency (json-ada or similar). All message types must be migrated from positional frames.
- Debugging encrypted ZMQ traffic requires application-level logging; standard network tools cannot inspect it. (Same as ADR-0009.)
- No operator-accessible file transfer channel. Operators who want to manually place a file must SSH into the node directly — this is debugging, not a production data plane.

### Neutral

- Agent-to-external-system transfers (e.g., log shipping via systemd-journal-remote) are out of scope. Each such use case selects its own native channel.
- The migration from positional frames to JSON is a one-time breaking change. No protocol versioning is prescribed at this stage; it may be addressed when Podmander reaches v1.0.

## References

- [ADR-0009](0009-zeromq-curve-for-control-plane.md) — ZeroMQ with CURVE for control plane (updated: alternatives section)
- [ADR-0010](0010-ssh-for-data-plane.md) — SSH for data plane (superseded by this ADR)
- [ADR-0032](0032-ssh-based-node-bootstrap.md) — SSH-based node bootstrap (abandoned)