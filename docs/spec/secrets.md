# Secrets Specification

Encrypted secret storage and delivery to containers.

For architectural decisions and rationale, see:
- [ADR-0021](../adr/0021-local-master-key-libsodium.md) — Local master key with libsodium encryption
- [ADR-0022](../adr/0022-agent-mediated-secret-delivery.md) — Agent-mediated secret delivery

## Storage

Secrets are stored encrypted in local SQLite using libsodium (secretbox).
Encryption happens at rest; secrets are only decrypted for delivery to nodes.

## Master Key

Options for providing the master encryption key:

- Passphrase at CLI invocation (prompted or via environment variable)
- File with restrictive permissions (`~/.config/podmander/master.key`)
- Hardware token (future)

The master key is required for any operation that reads or writes secrets:
- `podmander secret set/get/rm`
- `podmander deploy` (if services reference secrets)

## Delivery Flow

1. Operator runs `podmander deploy`
2. CLI identifies secrets referenced by services being deployed
3. CLI decrypts secrets locally using master key
4. Decrypted values are transmitted to the agent via the control/data plane
5. Agent pipes values to `podman secret create <name> -`
6. Quadlet references the secret by name

The secret value is never written to disk unencrypted on the node — it goes
directly from the agent to Podman's secret store.

### Podman Secret Storage

Podman stores secrets encrypted in the user's local storage:
- Rootless: `~/.local/share/containers/storage/secrets/`
- Rootful: `/var/lib/containers/storage/secrets/`

## Secret Updates

When a secret value changes:

```bash
podmander secret set myapp-db-password    # Prompts for new value
podmander deploy myapp.toml               # Re-deploys affected services
```

The deploy:
1. Removes the old Podman secret on affected nodes
2. Creates the new secret
3. Restarts containers that reference it

Services must be restarted to pick up new secret values — there is no hot-reload
mechanism.

## CLI Commands

```bash
podmander secret set <name>                # Set secret value (prompts for input)
podmander secret set <name> --file <path>  # Set from file
podmander secret list                      # List secret names (not values)
podmander secret rm <name>                 # Remove secret
```

## Transport Security

The secret value is:
1. Encrypted at rest in local SQLite (libsodium)
2. Decrypted in memory on the controller node
3. Transmitted via encrypted channel (CURVE/SSH)
4. Piped directly to `podman secret create` (never on disk unencrypted)
5. Encrypted at rest by Podman on the node

## Open Items

- Secret rotation mechanism (notify services, coordinated restarts)
- Hardware token integration for master key
- Secret access audit logging
- Secret synchronization check (verify node secrets match expected state)
