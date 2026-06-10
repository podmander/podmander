# AGENTS.md — Podmander

Podmander is a container orchestration system for small multi-node deployments.
It targets solo operators and small teams who need more than single-host Docker
Compose but less than Kubernetes. It generates configuration for specialized
tools (systemd, Podman, Caddy, Restic) rather than reimplementing their
functionality.

## Dev Environment

Builds, tests, and analysis commands need to run inside the `ada_dev` distrobox container. The `mise` build tool offers
preconfigured tasks for common development actions. They have the distrobox wrapping built in; run them from the host
system.

```bash
mise run build        # compile all binaries
mise run build:clean  # build everything from scratch
mise run test         # build and run the AUnit test suite
mise run format       # auto-format Ada sources (run this IMMEDIATELY when build shows style warnings)
mise run format:check # check formatting without modifying files
```

**Formatting rule:** When the build produces GNAT style warnings (indentation,
spacing, line length), do NOT try to fix them manually. Run `mise run format`
immediately and rebuild. Only address remaining warnings after formatting.

To enter an interactive shell directly:

```bash
distrobox enter ada_dev
```

## Project Management

### Labels

- `kind/` prefix: `epic`, `feature`, `refactor`, `bug`, `docs`, `infra`
- `area/` prefix: `controller`, `agent`, `protocol`, `cli`, `generator`, `ssh`, `secrets`

Epic issues (label: `kind/epic`) are top-level tracking issues with a checklist breakdown of work items.

### Milestones

Issues are grouped by release target.

### Session Handoff

When work on an epic pauses, leave a comment on the epic issue describing:
- What's done
- What's blocked
- What to do next

This is the handoff point for resuming work in a later session.

## Multi-Agent Workflow

All work happens in git worktrees managed by `wt`. Use the /version-control skill for details.

The main worktree is reserved for `wt switch` operations only.

## Implementation Process

1. Create a tracking issue if it doesn't exist yet. See "Issue Tracker" below.
2. Use the /version-control skill to create or switch to a feature worktree.
3. Do all coding work in the feature worktree.
4. If the session pauses, leave a handoff comment on the issue.
5. Push the branch and submit a pull request.
6. After merge, update the main worktree and remove the feature worktree.

## SQLite Gotchas

These recur whenever we touch the database layer.

- `PRAGMA journal_mode=WAL` cannot run inside a SQLite transaction. Execute
  it before `BEGIN`.
- `PRAGMA foreign_keys` is per-connection. You cannot observe it through a
  second connection to the same file.
- `ada_sqlite3.Open(":memory:")` works for tests (confirmed by upstream test
  suite). In-memory databases are isolated per connection — a second
  connection won't see the first connection's schema.

## Agent skills

### Issue tracker

Issues live as Forgejo issues (owner: `podmander`, repo: `podmander`). Use the Forgejo MCP server for all operations. See `notes/agents/issue-tracker.md`.

### Triage labels

Triage labels use a `triage/` prefix to match the existing `kind/` and `area/` convention. See `notes/agents/triage-labels.md`.

### Domain docs

Single-context repo. See `notes/agents/domain-docs.md`.

## Desired practices

- **Boy scout rule:** When you encounter pre-existing issues, fix them and
  commit these changes separately.

## Subagent Delegation Strategy

### Anti-patterns to avoid

- **Copy-paste delegation**: Never write exact code in a subagent prompt and
  expect it to paste it into files. Markdown code blocks lose indentation, and
  the subagent can't match GNAT style from markdown. If you've already designed
  the exact code, edit the files directly — no subagent needed.
