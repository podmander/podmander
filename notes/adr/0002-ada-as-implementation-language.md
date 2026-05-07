# ADR-0002: Ada as Implementation Language

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander is a systems-level orchestrator that manages containers, systemd units, file transfers, and encrypted secrets across multiple nodes. The implementation language needs to produce reliable, self-contained binaries that can be deployed to agent nodes without runtime dependencies.

Key forces:

- Long-running daemons (controller and agents) must be robust against memory errors and data corruption.
- The binary is deployed to nodes with minimal assumptions about installed runtimes.
- Strong typing can prevent entire classes of bugs at compile time (state machine transitions, protocol handling, configuration parsing).
- Concurrency is needed for handling multiple agent connections and parallel service operations.

## Decision

We will implement Podmander in Ada.

## Consequences

### Positive

- Strong static typing catches errors at compile time — distinct types for service names, version numbers, and node identifiers prevent accidental misuse.
- Built-in concurrency model (tasking, protected objects) maps naturally to the controller's concurrent agent handling.
- Compiles to native binaries with no runtime dependencies.
- SPARK subset available for formal verification of critical sections (secret handling, state transitions) if needed.
- Exception model with mandatory handling prevents silently swallowed errors.

### Negative

- Smaller ecosystem than Go or Rust — fewer third-party libraries available.
- Smaller hiring pool and community for contributions.
- Some library bindings (ZeroMQ, libsodium, SQLite) require Ada bindings or thin FFI wrappers.
- TOML parsing required a specific choice due to abandoned Ada YAML libraries (see [ADR-0004](0004-custom-toml-over-compose-yaml.md)).

### Neutral

- Ada's verbosity is a feature for infrastructure code — explicit is better than implicit in long-lived systems.

## Alternatives Considered

### Go

- Pros: Large ecosystem, good concurrency (goroutines), easy cross-compilation, strong community.
- Cons: Weaker type system (no discriminated records, no distinct types), garbage collection pauses in long-running daemons, error handling via convention rather than language enforcement.
- Why rejected: Type safety and compile-time guarantees outweigh ecosystem convenience for infrastructure-critical code.

### Rust

- Pros: Memory safety without GC, strong type system, growing ecosystem, good performance.
- Cons: Steeper learning curve, borrow checker complexity can slow development for concurrent systems, less mature concurrency story for actor-like patterns.
- Why rejected: Ada's tasking model is a more natural fit for the controller-agent concurrency pattern. Ada's longer track record in safety-critical systems is a better match for infrastructure management.
