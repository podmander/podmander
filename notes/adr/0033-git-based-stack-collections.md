# ADR-0033: Git-Based Stack Collections with Jinja Parameters

**Status**: Accepted
**Date**: 2026-04-12

## Context

Operators often deploy common software stacks (monitoring, databases, web applications). Sharing reusable stack definitions reduces duplication and enables community-maintained configurations. But shared stacks need customization — domain names, replica counts, resource limits differ between deployments.

Key forces:

- Stack sharing should use existing tools — no special registry, package manager, or distribution mechanism.
- Shared stacks need customization without forking or editing the shared files.
- The mechanism must be simple enough that operators can understand, debug, and contribute to shared stacks.
- Podmander's existing `podctl deploy <file>` command should work with shared stacks without modification.

## Decision

Stack definitions are shared via git repositories. Operators clone repositories containing TOML stack files and deploy from the local path. No special Podmander tooling is required — `podctl deploy <path>` works with any local file.

Stacks support Jinja-style `{{ name }}` parameters declared in a `[params]` section. Required and optional parameters with defaults enable customization without editing the shared stack file. Values are supplied via a separate params file at deploy time.

## Consequences

### Positive

- No special tooling — git clone, git pull, and `podctl deploy` are the entire workflow.
- Version pinning via git tags, branch selection via standard git workflows.
- Parameters enable customization without forking — operators supply their values in a separate file.
- Community-maintainable — standard git contribution workflows (PRs, issues, forks).
- No registry infrastructure to build, host, or maintain.

### Negative

- No dependency resolution between stacks — operators must manually deploy prerequisites.
- No semantic versioning enforcement — version discipline depends on repository maintainers.
- Jinja-style templating adds a parsing step and a template engine dependency.
- No discoverability mechanism — operators must find repositories themselves.

### Neutral

- Operators manage repository updates via standard git workflows (`git pull`, branch switching).
- Params file format is also TOML, consistent with the rest of the configuration.

## Alternatives Considered

### Custom stack registry (npm/Cargo-style)

- Pros: Discoverability, dependency resolution, semantic versioning, centralized search.
- Cons: Requires building and hosting registry infrastructure. Package publishing workflow. Versioning and dependency resolution are complex to implement correctly. Massive scope increase.
- Why rejected: Disproportionate complexity. Git repositories provide versioning, distribution, and collaboration without custom infrastructure.

### OCI registry for stacks (push stack TOML as OCI artifacts)

- Pros: Reuses container registry infrastructure. Standard pull/push workflow.
- Cons: Requires OCI registry access. Overloads the container image concept. No natural way to browse or diff stack definitions. Adds `oras` or similar tooling dependency.
- Why rejected: Git is a better fit for text-based configuration files. OCI registries are optimized for binary blobs (container images), not human-readable TOML.

### No parameterization (fork and edit)

- Pros: Simplest — no template engine, no params file, no parameter validation.
- Cons: Every deployment requires forking the shared stack. Updates from upstream require manual merging. Customization and versioning are conflated.
- Why rejected: Fork-and-edit does not scale. Parameters cleanly separate the shared definition from the deployment-specific values.

## References

- [ADR-0004](0004-custom-toml-over-compose-yaml.md) — Custom TOML schema (the format stacks use)
