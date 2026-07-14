# AGENTS.md — Podmander

Podmander is a container orchestration system for small multi-node deployments.
It targets solo operators and small teams who need more than single-host Docker
Compose but less than Kubernetes. It generates configuration for specialized
tools (systemd, Podman, Caddy, Restic) rather than reimplementing their
functionality.

## Dev Environment

The `mise` build tool offers preconfigured tasks for common development actions.

```bash
mise run build        # compile all binaries
mise run build:clean  # build everything from scratch
mise run test         # build and run the AUnit test suite
mise run format       # auto-format Ada sources
mise run format:check # check formatting without modifying files
```

**Formatting rule:** When the build produces GNAT style warnings (indentation,
spacing, line length), do NOT try to fix them manually. Run `mise run format`
immediately and rebuild. Only address remaining warnings after formatting.

## Project Management

### Labels

Issue **category** is an organization-level label (no prefix), shared across org repos: `bug`, `documentation`, `epic`, `feature`, `infra`, `refactor`, `test`.

Issue **triage state** is a repo-level `triage/` label: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `blocked`. See `notes/agents/triage-labels.md`.

Issues that will not be actioned get the organization-level `wontfix` label.

Epic issues (label: `epic`) are top-level tracking issues with a checklist breakdown of work items.

### Milestones

Issues are grouped by release target.

### Session Handoff

When work on an epic pauses, leave a comment on the epic issue describing:
- What's done
- What's blocked
- What to do next

This is the handoff point for resuming work in a later session.

## Implementation Process

All work happens in git worktrees managed by `wt`. Use the /version-control skill for details.

The main worktree is reserved for `wt switch` operations only.

1. Create a tracking issue if it doesn't exist yet. See "Issue Tracker" below.
2. Use the /version-control skill to create or switch to a feature worktree.
3. Use the /ada-coding skill to do all coding work in the feature worktree.
4. If the session pauses, leave a handoff comment on the issue.
5. Push the branch and submit a pull request.
6. After merge, update the main worktree and remove the feature worktree.

### Version bumps

When a change bumps the project version, update all release-facing version
sources in the same finishing commit:

- `alire.toml` package `version`
- `packaging/rpm/podmander.spec` `Version:` and `%changelog`
- `CHANGELOG.md` with a new release section; do not add new entries under an
  already-released version

Before committing a version bump, search the repository for the previous version
string and verify every remaining occurrence is intentional historical text.

## Dependencies

### CZMQ

The `czmq_ada` library provides Ada bindings to `libczmq`. Jochen maintains it, and there's a local
checkout of the code in `~/Projects/src/geewiz/czmq_ada/`.

### Sqlite

These gotchas recur whenever we touch the database layer:

- `PRAGMA journal_mode=WAL` cannot run inside a SQLite transaction. Execute
  it before `BEGIN`.
- `PRAGMA foreign_keys` is per-connection. You cannot observe it through a
  second connection to the same file.
- `ada_sqlite3.Open(":memory:")` works for tests (confirmed by upstream test
  suite). In-memory databases are isolated per connection — a second
  connection won't see the first connection's schema.

## Agent skills

The documents referenced in this section contain important information for working on this project.
Read them all now.

### Issue tracker

Issues live as Forgejo issues (owner: `podmander`, repo: `podmander`). Use the
Forgejo MCP server or the `fgj` CLI for Forgejo operations. See
`notes/agents/issue-tracker.md`.

### Triage labels

Triage state uses a repo-level `triage/` prefix; issue category uses shared organization-level labels. See `notes/agents/triage-labels.md`.

### Domain docs

Single-context repo. See `notes/agents/domain-docs.md`.

## Desired practices

- **Boy scout rule:** When you encounter pre-existing issues such as compiler warnings, fix them and commit these changes separately.

## Subagent Delegation Strategy

### Anti-patterns to avoid

- **Copy-paste delegation**: Never write exact code in a subagent prompt and
  expect it to paste it into files. Markdown code blocks lose indentation, and
  the subagent can't match GNAT style from markdown. If you've already designed
  the exact code, edit the files directly — no subagent needed.
