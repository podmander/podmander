# ADR-0010: SSH for Data Plane and Node Access

**Status**: Superseded by [ADR-0036](0036-zeromq-unified-transport.md)
**Date**: 2026-04-12

## Context

The controller needs to transfer files to agent nodes: Quadlet files, Caddyfiles, CoreDNS zone files, and Restic configuration. These transfers must be reliable, secure, and efficient when sending multiple files in sequence.

The control plane (ZeroMQ) handles commands and status (see [ADR-0009](0009-zeromq-curve-for-control-plane.md)). File transfer is a separate concern with different requirements: integrity guarantees, resumability for large files, and operator debuggability.

Key forces:

- Files must arrive intact — corrupted Quadlet files cause service failures.
- Operators need to be able to manually inspect and debug transfers when troubleshooting.
- Multiple files are often transferred in rapid succession during deploys — connection overhead matters.
- Nodes may be behind NAT or firewalls, requiring jump host support.

## Decision

We will use SSH/SCP for all file transfers from controller to agent nodes.

Files land in a staging directory (default `/tmp/podmander-stage/`, configurable). After transfer, the controller sends a `deploy:execute` command via ZeroMQ with file checksums. The agent verifies checksums before moving files to their target directory.

Connection efficiency is achieved via OpenSSH ControlMaster multiplexing, which reuses a single SSH connection for multiple transfers to the same node. Idle connections persist for a configurable duration (default 60 seconds).

Bastion/jump host support is available via SSH ProxyJump for nodes behind NAT or firewalls.

## Consequences

### Positive

- Battle-tested file transfer with integrity and encryption built in.
- ControlMaster multiplexing avoids repeated handshakes — efficient for multi-file deploys.
- Operators can manually SCP files or SSH into nodes for debugging using standard tools.
- Bastion/jump host support handles NAT and firewall scenarios without custom protocol extensions.
- Checksum verification in the staging directory catches transfer corruption before it affects services.

### Negative

- Requires SSH key distribution during node bootstrap — the controller's public key must be placed on each node.
- SSH access from the controller to all nodes is a broad privilege. Mitigation: dedicated SSH key, `command=` restrictions in `authorized_keys` for defense in depth.
- ControlMaster socket staleness (connection dropped but socket file remains) needs detection and cleanup.

### Neutral

- SSH is one-directional (controller → node). Agents do not initiate SSH connections.
- The staging-then-verify pattern adds a step compared to direct file placement, but prevents corrupted files from being activated.

## Alternatives Considered

### File transfer over ZeroMQ

- Pros: Single protocol for everything — no SSH dependency for file transfers.
- Cons: Requires implementing chunking, streaming, integrity verification, and resumability over ZeroMQ. No operator debugging with standard tools. ZeroMQ is designed for messages, not bulk file transfer.
- Why rejected: Reimplements battle-tested file transfer capabilities that SSH provides out of the box.

### rsync

- Pros: Delta transfers (only changed bytes), resume support, built on SSH.
- Cons: Adds a dependency (rsync must be installed on all nodes). Delta transfers are marginal benefit for the file sizes involved (Quadlets and configs are small). Adds complexity for minimal gain.
- Why rejected: Podmander's transferred files are small (configs, Quadlet definitions). Full file transfer via SCP is sufficient and has fewer dependencies.

### HTTPS file server on controller

- Pros: Agents pull files on demand — controller does not need SSH access to nodes.
- Cons: Requires TLS certificate management, an HTTP server on the controller, agent-side download logic, and a notification mechanism to trigger pulls. More complex than push-based SCP.
- Why rejected: Inverts the transfer direction without clear benefit. Adds complexity (HTTP server, TLS, pull triggers) to avoid SSH, which is already required for node bootstrap.

## References

- [ADR-0009](0009-zeromq-curve-for-control-plane.md) — ZeroMQ for control plane (the other half of the hybrid model)
- [ADR-0032](0032-ssh-based-node-bootstrap.md) — SSH-based node bootstrap (SSH is already required)
