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
