# ADR-0022: Agent-Mediated Secret Delivery via podman secret create

**Status**: Accepted
**Date**: 2026-04-12

## Context

Encrypted secrets stored in the controller's SQLite database (see [ADR-0021](0021-local-master-key-libsodium.md)) must reach containers on worker nodes. The delivery mechanism must ensure secrets are never written to disk unencrypted on the target node.

Key forces:

- Secret values must not be written to disk unencrypted at any point in the delivery chain.
- Podman has a built-in secret store (`podman secret create`) that handles at-rest encryption on the node side.
- The agent runs on each node and can execute Podman commands locally (see [ADR-0012](0012-rootless-containers-rootful-agent.md)).
- Quadlet files reference secrets by name — the secret must exist in Podman's store before the container starts.

## Decision

Secrets are delivered to containers via the agent, which creates them in Podman's secret store. The flow:

1. Controller decrypts secrets locally using the master key.
2. Controller transmits decrypted secret values to the agent via the existing communication channels (ZeroMQ control plane and/or SSH data plane — see [ADR-0009](0009-zeromq-curve-for-control-plane.md), [ADR-0010](0010-ssh-for-data-plane.md)).
3. The agent pipes the secret value directly into `podman secret create <name> -` — the value goes from stdin to Podman's encrypted store without touching the filesystem.
4. Quadlet files reference the secret by name.

When a secret value changes, the agent removes the old Podman secret, creates the new one, and restarts dependent containers.

## Consequences

### Positive

- Secrets are never written to disk unencrypted — they go from encrypted storage (SQLite) through encrypted transport (CURVE/SSH) to encrypted storage (Podman's secret store).
- Leverages Podman's built-in secret management — no custom secret storage on nodes.
- The agent handles the Podman interaction locally, keeping the delivery mechanism simple.
- Secret references in Quadlet files use names, not values — Quadlet files are safe to inspect.

### Negative

- Secret updates require container restarts — there is no hot-reload mechanism. Services must be designed to tolerate restarts for secret rotation.
- The agent has transient access to decrypted secret values (in memory, during the `podman secret create` call). Mitigation: the agent already runs as root, so this does not expand its trust boundary.
- Secret synchronization between the controller's database and each node's Podman secret store must be verified. Verification is a future extension.

### Neutral

- Secrets have a separate lifecycle from service versions — they are not versioned alongside service definitions (see [ADR-0023](0023-per-service-monotonic-versioning.md)).
- The same secret name can be referenced by multiple services across the fleet.

## Alternatives Considered

### Write secret files to disk via SSH

- Pros: Simple — SCP a file, reference it in the container. No Podman secret store dependency.
- Cons: Secret values exist as plaintext files on the node's filesystem. Even with restrictive permissions, this is a larger attack surface. Cleanup (deleting old files) is error-prone.
- Why rejected: Unencrypted secret files on disk violate the security requirement. Podman's secret store provides at-rest encryption for free.

### Inject secrets as environment variables in Quadlet files

- Pros: No Podman secret store dependency. Environment variables are familiar to operators.
- Cons: Secret values are written in plaintext in Quadlet files on disk. Visible in `podman inspect`, process listings, and systemd unit files. Significantly weaker security posture.
- Why rejected: Plaintext secrets in configuration files is the weakest option. Podman secrets are purpose-built for this use case.

### Controller pushes secrets directly (no agent involvement)

- Pros: Removes agent from the trust chain for secrets.
- Cons: The controller would need to execute `podman secret create` remotely via SSH, which requires understanding the target Podman user (rootless vs rootful) and managing Podman CLI invocations remotely. The agent already handles all Podman interactions — bypassing it for secrets adds a separate code path.
- Why rejected: The agent is already the trusted executor for all Podman operations on the node. Adding a separate SSH-based path for secrets duplicates logic and complicates the architecture.

## References

- [ADR-0021](0021-local-master-key-libsodium.md) — Local master key with libsodium encryption (encryption at rest)
- [ADR-0009](0009-zeromq-curve-for-control-plane.md) — ZeroMQ with CURVE encryption (transport encryption)
- [ADR-0010](0010-ssh-for-data-plane.md) — SSH for data plane (transport encryption)
- [ADR-0012](0012-rootless-containers-rootful-agent.md) — Rootless containers with rootful agent (agent trust boundary)
