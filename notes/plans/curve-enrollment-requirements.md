# CURVE Enrollment Requirements

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-15

## Problem Frame

The controller and agents communicate over ZeroMQ ROUTER/DEALER sockets without encryption. Any node on the network can intercept or impersonate controller-agent messages. We need mutual authentication and encrypted communication using CURVE (libsodium-based).

## Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R1 | Controller generates a CURVE certificate keypair on cluster initialization | Must Have | Must be usable for HA (shared storage) |
| R2 | Join token format: `PTKN-<z85-controller-pubkey>-<hex-enrollment-secret>` | Must Have | Must be printable ASCII for easy copy-paste during bootstrap |
| R3 | Agent generates its own CURVE certificate on startup | Must Have | Used for mutual authentication |
| R4 | Controller runs in CURVE server mode (authenticates clients) | Must Have | Uses Set_Curve_Server (True) |
| R5 | Agent uses CURVE client mode with server key verification | Must Have | Uses Set_Curve_Serverkey with controller pubkey from token |
| R6 | Enrollment secret is generated once at cluster init and stored | Must Have | Used to validate agent enrollment requests |
| R7 | Controller validates enrollment secret before completing registration | Must Have | Prevents unauthorized agent enrollment |

## Success Criteria

1. Wireshark or similar cannot decrypt controller-agent traffic
2. Agent without valid join token cannot connect even if it has correct controller address
3. Agent with valid join token but wrong certificate cannot connect
4. Multiple agents can connect simultaneously to same controller
5. Controller and agent can reconnect after network interruption without re-enrollment

## Scope Boundaries

**In scope:**
- CURVE certificate generation and management
- Join token format and generation
- Enrollment secret validation
- Socket-level CURVE configuration

**Out of scope:**
- Key storage/replication for HA (defer to later issue)
- Key rotation for existing enrolled agents
- Certificate renewal mid-operation

## Key Decisions

| Decision | Chosen | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Join token format | PTKN-\<pubkey\>-\<secret\> | Single printable string, easy to copy-paste during bootstrap | Separate pubkey and secret as separate files |
| Enrollment secret length | 32 hex chars (128 bits) | Sufficient entropy, easy to read/transcribe | Longer secret, base85 encoding |
| Agent key storage | Generate fresh on each startup | Simpler, no persistence needed for read-only agents | Persist agent certificate to disk |

## Outstanding Questions

| # | Question | Impact if Wrong | Owner |
|---|----------|-----------------|-------|
| Q1 | Should the enrollment secret be stored in plaintext or hashed on the controller? | Plaintext needed to validate agents, but risk if controller compromised | Controller design decision |
| Q2 | Do we need a mechanism to revoke enrolled agents (blocklist)? | Not needed for initial implementation but would prevent re-enrollment of compromised agents | Future enhancement |