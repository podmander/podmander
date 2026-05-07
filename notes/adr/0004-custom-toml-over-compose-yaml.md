# ADR-0004: Custom TOML Schema over Docker Compose YAML

**Status**: Accepted
**Date**: 2026-04-12

## Context

Podmander needs a configuration format for service definitions, volumes, secrets, and cluster settings. The most familiar option would be Docker Compose's YAML format, which has broad adoption and existing tooling.

Key forces:

- The Ada ecosystem lacks a maintained YAML library (AdaYaml is abandoned).
- Podmander's feature set diverges from Docker Compose (placement rules, multi-node scheduling, infrastructure components, stack parameters). Adopting Compose syntax would mean extending it in non-standard ways or constraining Podmander's design.
- TOML is already the configuration language of the Podman ecosystem (Quadlets, `containers.conf`).
- A migration helper (`podctl convert`) can reduce the barrier for users coming from Docker Compose.

## Decision

We will define a custom TOML schema for Podmander configuration, not adopt Docker Compose YAML.

Stack definitions use Jinja-style `{{ name }}` placeholders with a `[params]` section for customization. Stacks are shared via git repositories using standard git workflows — no special tooling required.

## Consequences

### Positive

- Freedom to design a schema that maps directly to Podmander's concepts (placement rules, infrastructure components, stack parameters) without shoehorning into Compose semantics.
- Consistent with the Podman/Quadlet ecosystem's use of TOML.
- TOML has cleaner syntax with no significant-whitespace pitfalls.
- Available Ada TOML libraries are maintained.

### Negative

- No existing tooling ecosystem (linters, IDE extensions, documentation) for the custom schema.
- Users migrating from Docker Compose must learn a new format.
- The `podctl convert` migration helper adds development scope.

### Neutral

- Git-based stack collections require no special Podmander tooling — `podctl deploy <path>` works with any local file.

## Alternatives Considered

### Docker Compose YAML (adopt the format)

- Pros: Familiar to most container users, extensive tooling, broad documentation.
- Cons: No maintained Ada YAML parser. Podmander's features (multi-node placement, infrastructure components, stack parameters) do not map to Compose concepts. Extending Compose syntax creates a non-standard dialect that confuses users expecting standard behavior.
- Why rejected: Technical blocker (no Ada YAML library) combined with semantic mismatch between Compose and Podmander's orchestration model.

### HCL (HashiCorp Configuration Language)

- Pros: Designed for infrastructure configuration, used by Terraform/Nomad.
- Cons: No Ada parser. More complex than needed — HCL's block syntax and expression language are designed for Terraform's plan/apply model, not Podmander's simpler declare-and-deploy approach.
- Why rejected: No Ada parser, and the complexity is not warranted.
