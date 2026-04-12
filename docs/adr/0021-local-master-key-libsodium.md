# ADR-0021: Local Master Key with libsodium Encryption

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander stores secrets (database passwords, API keys, TLS certificates) in the controller's SQLite database. These secrets must be encrypted at rest — a stolen or backed-up database file should not expose secret values.

Key forces:

- The encryption scheme must not require an external service (no HashiCorp Vault, no cloud KMS). The target audience runs small-scale infrastructure and should not need additional infrastructure for secret management.
- The master key must be available when secrets are read (during deploys) but should not be stored alongside the encrypted data.
- The cryptographic library must be well-audited, widely available, and have Ada bindings or a clean FFI surface.

## Decision

Secrets are encrypted at rest in SQLite using libsodium's `secretbox` (XSalsa20-Poly1305). A single master key encrypts all secrets.

The master key can be provided via:

1. **Passphrase** — prompted at CLI invocation or via environment variable.
2. **Key file** — stored at `~/.config/podmander/master.key` with restrictive permissions.
3. **Hardware token** — future extension.

The master key is required for any operation that reads or writes secrets (`podmander secret set/get/rm`, `podmander deploy` when services reference secrets).

## Consequences

### Positive

- No external infrastructure dependency — encryption is local and self-contained.
- libsodium is well-audited, widely available, and provides authenticated encryption (secretbox prevents both decryption and tampering without the key).
- Multiple key provisioning options balance security (passphrase) with convenience (key file).
- Backed-up database files are safe without the master key — secrets remain encrypted.

### Negative

- Single master key — compromise of the key exposes all secrets. Mitigation: key file permissions, hardware token support (future).
- No key rotation mechanism — changing the master key requires re-encrypting all secrets. Future extension.
- Master key must be available on the controller node — the controller needs it to decrypt secrets during deploys.
- The master key itself must be backed up separately from the database.

### Neutral

- libsodium is a C library — requires Ada thin bindings or FFI. This is a common pattern for Podmander's external library dependencies (ZeroMQ, SQLite).

## Alternatives Considered

### HashiCorp Vault

- Pros: Purpose-built secret management, key rotation, audit logging, access control.
- Cons: External infrastructure dependency. Requires running, maintaining, and backing up a Vault instance. Overkill for the target deployment size.
- Why rejected: Podmander should not require external infrastructure for core functionality. Operators who need Vault can deploy it as a Podmander service and manage secrets externally.

### Age (age-encryption.org)

- Pros: Simple, modern encryption tool. File-based. Good CLI UX.
- Cons: Designed for file encryption, not programmatic use. No stable library API — would require shelling out to the `age` CLI. No Ada bindings.
- Why rejected: Not suitable for programmatic encryption/decryption within a long-running daemon. No library interface.

### GPG

- Pros: Widely available, supports hardware tokens natively.
- Cons: Complex API, configuration-heavy, poor ergonomics for programmatic use. Key management is notoriously difficult.
- Why rejected: Complexity and poor developer ergonomics. libsodium provides a simpler, more modern API with equivalent security.

## References

- [ADR-0022](0022-agent-mediated-secret-delivery.md) — Agent-mediated secret delivery (how decrypted secrets reach containers)
- [ADR-0003](0003-sqlite-for-controller-state.md) — SQLite for controller state (where encrypted secrets are stored)
