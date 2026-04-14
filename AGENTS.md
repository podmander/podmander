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

- Use `--` comments, not block comments.
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
