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

## Ada Patterns for Subagents

These patterns recur frequently. Internalize them instead of rediscovering them.

### Limited types

Ada limited types cannot be assigned with `:=`. They can only be initialized
by function return. This affects both production code and tests:

```ada
--  WRONG: assignment to limited type
Handle : DB_Handle;
Handle := DB.Open (Path);

--  RIGHT: initialization by function return
Handle : DB_Handle := DB.Open (Path);

--  RIGHT in declare blocks (common in tests)
declare
   H : DB_Handle := DB.Open (Path);
begin
   null;  --  H auto-finalizes when block exits
end;
```

### Controlled finalization

Types extending `Limited_Controlled` auto-finalize their controlled component
fields. Do NOT call `.Finalize` on components explicitly — that causes
double-finalization. Override `Finalize` only when you need cleanup beyond
what the component's own finalization provides. An empty override is valid.

### Private fields

Never add accessors to private fields just for testing. Test observable
behavior through the public API. For database tests, open a second
`Ada_Sqlite3.Database` connection to the same file to verify schema state.

### Package hierarchy and circular dependencies

Ada prohibits a parent package from `with`ing its own child. If
`Podmander.Controller` needs to use `Podmander.Controller.Database`, the
child must be moved out of the parent hierarchy (e.g., to
`Podmander.Database`). Consider this constraint when designing new packages.

### `use type` for enumeration comparisons

Comparing enumeration values from another package requires visibility:

```ada
use type Ada_Sqlite3.Result_Code;  --  enables Step = ROW comparison
```

### Exception message format

The `ada_sqlite3` library formats `SQLite_Error` messages as:
`"<description> (Error code: <n>)"`. Parse the parenthesized suffix to
extract the numeric code. `Constraint_Error` (not `Value_Error`) is the
exception raised by failed `'Value` attribute conversions.

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

- **Orchestrator doing implementation work**: If the spec is clear and the
  work is more than ~20 lines, delegate to @fixer. The orchestrator lacks
  the execution speed and makes more compilation errors than @fixer.
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
