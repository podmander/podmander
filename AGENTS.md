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

## Code Style Guidelines

### File Organization

- One package per file pair (`.ads` spec + `.adb` body).
- File names match package names with dots replaced by hyphens: `Podmander.Scheduler` lives in `podmander-scheduler.ads/.adb`.
- Group files by component: `src/cli/`, `src/core/`, `src/ssh/`, `src/generators/`.
- Test files mirror source structure under `tests/`.

### Naming Conventions

- **Packages**: Mixed_Case with dots for hierarchy (`Podmander.Controller.State`).
- **Types**: Mixed_Case with `_Type` suffix only when needed to avoid ambiguity. Prefer descriptive names: `Service_Definition`, `Node_Status`.
- **Subprograms**: Mixed_Case verbs for procedures (`Deploy_Service`), nouns/adjectives for functions (`Is_Healthy`, `Current_Version`).
- **Constants**: All_Upper_Case (`Max_Retry_Count`).
- **Variables**: Mixed_Case (`Active_Services`).
- **Parameters**: Mixed_Case, use named association in calls when there are more than two parameters.
- **Enumeration literals**: Mixed_Case (`Pending`, `Active`, `Superseded`, `Failed`).

### Formatting

- Maximum line length: 120 characters.
- Indentation: 3 spaces (Ada standard).
- No tabs.
- One blank line between subprogram bodies.
- Align `=>` in aggregates and named associations when it improves readability.

### Types and Safety

- Use strong typing. Define distinct types rather than aliasing Standard types:
  ```ada
  type Service_Name is new String (1 .. 64);
  type Version_Number is new Positive;
  ```
- Use subtypes with constraints to enforce invariants at the type level.
- Prefer enumerations over magic strings or integers for state values.
- Use `not null access` when a pointer must never be null.
- Avoid `Unchecked_Deallocation` — prefer controlled types or container ownership.
- Prefer tagged types (OOP style) for polymorphism and extensibility.
- Use interface types for driver abstractions (e.g., tool backends, storage). Promote to abstract tagged types only when implementations share state or behavior.

### Error Handling

- Use exceptions for truly exceptional conditions (I/O failures, corrupt state).
- Use discriminated records or status enums for expected failure modes:
  ```ada
  type Deploy_Result (Success : Boolean) is record
     case Success is
        when True  => Version : Version_Number;
        when False => Reason  : Unbounded_String;
     end case;
  end record;
  ```
- Never silently swallow exceptions. Catch, log, and re-raise or convert to a result type.
- Define project-specific exception hierarchy under `Podmander.Errors`.

### Ada-Specific Practices

- Use `pragma Preelaborate` or `pragma Pure` where possible.
- Use `limited with` to break circular dependencies between specs.
- Prefer Ada.Containers (Vectors, Maps, Sets) over hand-rolled data structures.
- Use SPARK annotations for critical subsections (secret handling, state transitions) if practical.
- Prefer tasking and protected objects over raw OS threading primitives.

### Documentation

- Keep comments factual. Describe "why," not "what" when the code is self-explanatory.
- At the beginning of each source code file, add the SPDX-style Apache 2.0 header. The full license text lives in the top-level `LICENSE` file. Template:
    ```ada
    --  Copyright (C) <year> Jochen Lillich
    --  SPDX-License-Identifier: Apache-2.0
    ```

## Testing Strategy

- Use AUnit for unit tests.
- Test files go under `tests/` mirroring the source tree.
- Each test package name ends with `_Tests` (e.g., `Podmander.Controller.Scheduler_Tests`).
- Test procedure names describe the scenario: `Test_Deploy_Creates_Version_Record`.
- Test against interfaces, not internals. Mock external tools (BTRFS, ZFS, Podman, systemd) behind driver abstractions.
- Integration tests that exercise actual tool execution go in `tests/integration/` and are gated behind a flag so they don't run in CI without the required host tooling.

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
