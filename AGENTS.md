# AGENTS.md — Podmander

Podmander is a container orchestration system for small multi-node deployments.
It targets solo operators and small teams who need more than single-host Docker
Compose but less than Kubernetes. It generates configuration for specialized
tools (systemd, Podman, Caddy, Restic) rather than reimplementing their
functionality.

## Dev Environment

All build, test, and analysis commands run inside the `ada_dev` distrobox container.
Use Alire (`alr`) for builds and dependency management.

```bash
# Enter an interactive shell
distrobox enter ada_dev

# Run a single command
distrobox enter ada_dev -- alr build
```

## Project Management

All work is tracked in Forgejo (owner: `podmander`, repo: `podmander`).

### Labels

- `kind/` prefix: `epic`, `feature`, `refactor`, `bug`, `docs`, `infra`
- `area/` prefix: `controller`, `agent`, `protocol`, `cli`, `generator`, `ssh`, `secrets`

Epic issues (label: `kind/epic`) are top-level tracking issues with a checklist breakdown of work items.

### Milestones

Issues are grouped by release target. Current milestone: **v0.1 MVP**.

### Session Handoff

When work on an epic pauses, leave a comment on the epic issue describing:
- What's done
- What's blocked
- What to do next

This is the handoff point for resuming work in a later session.

## Multi-Agent Workflow

All work happens in git worktrees managed by `wt`. The main worktree is reserved for `wt switch` operations only.

- Create: `wt switch --create <issue>-<stub>`
- Build: `distrobox enter ada_dev -- alr build`
- Test: `distrobox enter ada_dev -- alr test`
- Clean up: `wt switch main && wt remove <issue>-<stub>`

Never edit or build in the main worktree while another agent is active.

## Implementation Process

1. Create an issue via the Forgejo MCP.
2. In the main worktree, run `wt switch --create <issue-number>-<short-stub>`.
3. Do all coding work in the worktree.
4. If the session pauses, leave a handoff comment on the issue.
5. Push the branch and submit a pull request via Forgejo MCP.
6. After merge, remove the worktree: `wt remove <issue-number>-<short-stub>`.

## SQLite Gotchas

These recur whenever we touch the database layer.

- `PRAGMA journal_mode=WAL` cannot run inside a SQLite transaction. Execute
  it before `BEGIN`.
- `PRAGMA foreign_keys` is per-connection. You cannot observe it through a
  second connection to the same file.
- `ada_sqlite3.Open(":memory:")` works for tests (confirmed by upstream test
  suite). In-memory databases are isolated per connection — a second
  connection won't see the first connection's schema.

## Subagent Delegation Strategy

### When to delegate

- **@fixer** for bounded implementation work: writing production code and
  tests when the spec is clear. Give precise, scoped instructions with file
  paths and expected patterns. Keep prompts under ~2000 words — if longer,
  split into multiple @fixer calls.
- **@oracle** for architectural review of plans and code, *between planning
  and implementation*. High-value for catching design issues before code is
  written.
- **@librarian** (not @explorer) for external library API research. @explorer
  searches the local codebase; @librarian searches documentation and examples.
- **@explorer** for local codebase discovery: finding files, patterns, and
  existing code locations.

### When NOT to delegate

- Single-file changes under ~20 lines.
- Work tightly coupled to your current train of thought.
- Decisions that need user approval first (e.g., package renames).

### Anti-patterns to avoid

- **Copy-paste delegation**: Never write exact code in a fixer prompt and
  expect it to paste it into files. Markdown code blocks lose indentation,
  and the fixer can't match GNAT style from markdown. If you've already
  designed the exact code, edit the files directly — no subagent needed.
- **Orchestrator doing implementation work**: If the spec is clear and the
  work is more than ~20 lines, delegate to @fixer with *design guidance*
  (what to change, where, constraints, patterns to follow from existing
  code), not exact code. The fixer reads the actual files and matches the
  existing style.
- **Tests as a separate phase**: @fixer must follow TDD Red-Green — write
  the failing test first, then make it pass. Never batch all tests at the
  end.
- **Rewriting on compilation errors**: When Ada compilation fails, read the
  error message, fix the specific issue, and rebuild. Don't rewrite the
  whole unit from scratch.

### Common pitfalls

- **Distrobox**: All `alr build`/`alr test` commands MUST run via
  `distrobox enter ada_dev --`. Subagents need this in every prompt.
- **Prompt length**: If a @fixer prompt exceeds the tool limit, split the
  work into smaller scoped tasks (e.g., one @fixer for tests, another for
  production code).
- **Architectural decisions**: If a @fixer encounters a design constraint
  (like Ada's circular dependency rule), it should surface the issue rather
  than silently restructuring. Flag these in the prompt: "If you encounter
  a design constraint that requires an architectural change, stop and report
  it instead of making the change."

## Agent skills

### Issue tracker

Issues live as Forgejo issues (owner: `podmander`, repo: `podmander`). Use the Forgejo MCP server for all operations. See `notes/agents/issue-tracker.md`.

### Triage labels

Triage labels use a `triage/` prefix to match the existing `kind/` and `area/` convention. See `notes/agents/triage-labels.md`.

### Domain docs

Single-context repo. See `notes/agents/domain.md`.
