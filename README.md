# Podmander

Container orchestration for multi-node deployments where Kubernetes is overkill. More than Docker Compose, less than Kubernetes.

Podmander generates configuration for proven tools — systemd, Podman, Caddy, Restic, ZFS — rather than reimplementing what they already do well.

## Status

**Early implementation.** See the [v0.1 MVP milestone](https://code.monospacementor.com/podmander/podmander/milestones) and [project board](https://code.monospacementor.com/podmander/podmander/projects) for progress.

## Key Ideas

- Single controller, multiple worker agents
- Rootless Podman containers by default
- Custom TOML configuration (not Compose YAML)
- Quadlet files for systemd integration
- BTRFS/ZFS volume snapshots and rollback
- Encrypted secrets with libsodium
- Written in Ada

## Development notes

- [`notes/adr/`](notes/adr/) — Architecture Decision Records
- [`notes/spec/`](notes/spec/) — Specifications
- [`notes/plans/`](notes/plans/) — Implementation plans
- [`notes/brainstorms/`](notes/brainstorms/) — Design explorations

## Testing

Run the AUnit test suite with:

```sh
mise run test
```

`podmander_tests.gpr` builds the test runner from `tests/`. Each test package
defines an AUnit suite, and `tests/test_runner.adb` explicitly registers every
suite with the runner.

To add a test suite, create its specification and body in `tests/`, implement
its `Suite` function, then import the package and add its suite to
`tests/test_runner.adb`. See `tests/podmander-enrollment_tests.ads` and
`tests/podmander-enrollment_tests.adb` for an example.

## Project Management

We track all work in Forgejo issues, organized as follows:

### Labels

Labels group issues by category (`kind/`) and code area (`area/`).

| Prefix | Values | Purpose |
|--------|--------|---------|
| `kind/` | `epic`, `feature`, `refactor`, `bug`, `docs`, `infra` | What kind of work is this? |
| `area/` | `controller`, `agent`, `protocol`, `cli`, `generator`, `ssh`, `secrets` | Which part of the codebase? |

The `kind/epic` label marks top-level tracking issues with a checklist breakdown.

### Epics

Epic issues are long-lived tracking issues that describe a major capability (e.g., "SQLite state storage"). Each epic contains:

- **Goal** — what the epic achieves
- **Context** — why it matters and relates to ADRs
- **Breakdown** — a checklist of concrete work items
- **Out of Scope** — explicitly excluded work
- **Dependencies** — blocking issues (via Forgejo issue dependencies)

Work issues reference their epic with `Part of #N` in the body and are set as blocking dependencies on the epic.

### Milestones

Milestones group issues by release target. The current milestone is **v0.1 MVP**: controller and agent can deploy a single service to a node, with SQLite state storage, TOML config, and basic CLI.
