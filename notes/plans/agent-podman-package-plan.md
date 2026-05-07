# Agent Podman Package Implementation Plan

## Architecture

`Podmander.Agent.Podman` becomes the home for every agent-side
operation that drives Podman or Podman-adjacent system tooling
(systemd, `~/.config/containers/systemd/...`). It mirrors the shape
of `Podmander.Agent.Host_Command`: one package, multiple operations,
no premature subdivision into Quadlet/Container subpackages.

Today the namespace holds two operations, both invoked from the
agent's message-handler dispatch:

```
Podmander.Agent.Message_Handlers
  │
  ├─▶ Handle_Deploy_Command  ─▶ Podman.Install_Quadlet
  │
  └─▶ Handle_Status_Query    ─▶ Podman.List_Containers
```

`Install_Quadlet` and `List_Containers` keep the existing wire-shaped
return types (`Deploy_Result`, `Status_Response`) so this refactor
does not touch the protocol layer.

Future host-side capabilities (Caddy, Restic, zone files) get sibling
agent-scoped packages — `Podmander.Agent.Caddy`,
`Podmander.Agent.Restic`, etc. The Podman package does not absorb
non-Podman operations.

---

### Unit 1: Move Deploy flow into Podmander.Agent.Podman.Install_Quadlet

**Goal:** Replace `Podmander.Agent.Deployer.Execute_Deploy` with
`Podmander.Agent.Podman.Install_Quadlet` and create the new package
shell. After this unit, the deploy chain runs through the new
namespace; `Status_Collector` is still in place.

**Dependencies:** None.

**Files:**
- `src/agent/podmander-agent-podman.ads` (new) — package spec, declares
  `Install_Quadlet (Service_Name : String; Quadlet : String) return
  Podmander.Messages.Deploy_Results.Deploy_Result;` plus a brief
  package-level header comment ("Host-side Podman/Quadlet operations
  invoked by the agent").
- `src/agent/podmander-agent-podman.adb` (new) — package body containing
  the implementation moved verbatim from `Deployer.Execute_Deploy`,
  with one rename (procedure name) and updated package qualifier.
- `src/agent/podmander-agent-deployer.ads` (delete via `git rm`).
- `src/agent/podmander-agent-deployer.adb` (delete via `git rm`).
- `src/agent/podmander-agent-message_handlers.adb` — replace
  `with Podmander.Agent.Deployer;` with
  `with Podmander.Agent.Podman;`. In `Handle_Deploy_Command`, change
  `Podmander.Agent.Deployer.Execute_Deploy (...)` to
  `Podmander.Agent.Podman.Install_Quadlet (...)`. Argument list and
  return type are unchanged.
- `src/agent/podmander-agent-message_handlers.ads` — update the
  package-header comment from "domain packages (Deployer,
  Status_Collector)" to "domain packages (Podman, Status_Collector)".
  The Status_Collector reference is removed by Unit 2.

**Approach:** Plain create-then-delete, not `git mv`. The body content
moves with one functional edit (`Execute_Deploy` → `Install_Quadlet`)
and one structural edit (package wrapping), so a rename-detection
pass would be misleading. The package body's existing helpers (`HC`,
`RM`, `RC` renames; the systemctl invocations) all carry over
verbatim. Run `alr build` after the new files are in place and
before the old files are removed, so a missing reference fails fast.

**Patterns:**
- Match the package-header style of `Podmander.Agent.Host_Command`
  (single-line domain summary, no boilerplate).
- Keep the `package HC renames Podmander.Agent.Host_Command;` and
  `package RM renames …;` style aliases inside the body — they make
  the systemctl call sites readable.
- Use the existing `Ada.Directories.Create_Path` + `Ada.Text_IO.Create`
  flow for writing the Quadlet file. No restructuring there.

**Test scenarios:**
- [ ] `alr build` succeeds with both old and new files present, then
      again after the old files are removed.
- [ ] `alr test` reports 45/45. Note: this verifies no compilation
      regression only — the existing 45 tests do not exercise the
      `Execute_Deploy` / `Install_Quadlet` body via the message-handler
      chain (controller dispatch tests use `Spy_Handler`; the agent
      side has no direct test for this path). Behaviour preservation
      is therefore verified by reading the moved body, not by tests.
- [ ] `git grep -E '\bPodmander\.Agent\.Deployer\b'` returns no hits in
      `src/` or `tests/`.
- [ ] `git grep -E '\bExecute_Deploy\b'` returns no hits.
- [ ] The deploy code path (file write → daemon-reload → start) still
      runs in the order the original `Execute_Deploy` did, by inspection
      of the moved body.

**Verification:** Both binaries (`pod_controller`, `pod_agent`) link
cleanly; no warnings new in this commit; the diff shows two new files
and two deletions in `src/agent/`, plus the message-handler edits.

**Planning-time unknowns:** None.

---

### Unit 2: Move status-query flow into Podmander.Agent.Podman.List_Containers

**Goal:** Add `List_Containers` to the existing `Podmander.Agent.Podman`
package and remove `Podmander.Agent.Status_Collector`. After this
unit, the Podman namespace holds both operations and the
Status_Collector files are gone.

**Dependencies:** Unit 1 (the package must exist before adding a
second operation to it).

**Files:**
- `src/agent/podmander-agent-podman.ads` — extend the existing spec
  with `List_Containers return Podmander.Messages.Status_Responses.
  Status_Response;`.
- `src/agent/podmander-agent-podman.adb` — add the body of
  `List_Containers`, moved from `Status_Collector.Collect_Status`.
  No-arg function returning a Status_Response, runs `podman ps
  --format "{{.Names}} {{.Status}}"`, wraps result.
- `src/agent/podmander-agent-status_collector.ads` (delete via
  `git rm`).
- `src/agent/podmander-agent-status_collector.adb` (delete via
  `git rm`).
- `src/agent/podmander-agent-message_handlers.adb` — remove
  `with Podmander.Agent.Status_Collector;`. In `Handle_Status_Query`,
  change `Podmander.Agent.Status_Collector.Collect_Status` to
  `Podmander.Agent.Podman.List_Containers`.
- `src/agent/podmander-agent-message_handlers.ads` — finalise the
  package-header comment. With both renames done the comment reduces
  to "domain packages (Podman)"; alternatively reword to "the
  host-side capability packages" for durability as Caddy/Restic land.
  Pick one in the commit and stick with it.

**Approach:** Same shape as Unit 1 — create the new operation in the
existing package, update the caller, then remove the old files.
Because Status_Collector is a single-op package, the new operation
adds no helpers and no additional with-clauses to the Podman body
beyond what Unit 1 already pulled in (Host_Command, Logging,
Result_Codes, Status_Responses).

**Patterns:**
- Preserve the existing exception envelope at the bottom of
  `Collect_Status` (catches `others`, returns
  `Status_Response (Code => Internal, ...)`). That envelope is the
  agent's last line of defence against a runaway Podman invocation
  and must not be dropped.
- Keep the `(if Length (Result.Error_Output) > 0 then Result.Error_Output
  else Result.Output)` fallback for error reporting — it preserves the
  current behaviour when Podman writes to stdout instead of stderr on
  some failures.

**Test scenarios:**
- [ ] `alr build` succeeds before and after the Status_Collector
      removal.
- [ ] `alr test` reports 45/45. Same caveat as Unit 1: this verifies
      no compilation regression. The 45 existing tests do not exercise
      `Collect_Status` / `List_Containers` via the dispatch chain.
- [ ] `git grep -E '\bPodmander\.Agent\.Status_Collector\b'` returns no
      hits in `src/` or `tests/`.
- [ ] `git grep -E '\bCollect_Status\b'` returns no hits.
- [ ] `Handle_Status_Query` (`message_handlers.adb`) calls
      `Podman.List_Containers` and the returned `Status_Response` is
      sent back via `Send_Status_Response`. Read-only verification —
      same path as before, only the producer changed.

**Verification:** Both binaries link cleanly; the message_handlers
spec comment reflects only the Podman package (or a generic
host-side phrasing); the diff shows Podman package gaining one
function, Status_Collector files deleted, message_handlers updated.

**Planning-time unknowns:** None.

---

## Out of Scope

- Renaming or restructuring the wire types `Deploy_Result` and
  `Status_Response`. The function names move to a domain noun-phrase;
  the wire shapes stay as today.
- Adding direct unit tests for `Install_Quadlet` and `List_Containers`.
  Both shell out to host tools (`systemctl`, `podman`) and have no
  unit-level seam to mock against; integration tests belong in the
  `tests/integration/` harness AGENTS.md describes, gated behind a
  flag, and that harness does not exist yet.
- New host-side capabilities (Caddy, Restic, zone files). They will
  get their own agent-scoped sibling packages later.
- Renaming `Handle_Deploy_Command` / `Handle_Status_Query`. Those are
  protocol primitives; their names track the wire kinds and are out
  of scope here.
- Collapsing the duplicated `Daemon_Reload` / `Start_Service` blocks
  inside the moved-and-renamed `Install_Quadlet` body. They share an
  identical "build args, run command, check result, return failure"
  shape and would collapse into a small helper, but doing that on the
  same diff would muddy the rename. Track as a separate follow-up
  cleanup once this lands.

## Quality Bar Checklist

- [x] Every unit traces to the issue scope (Podman home + two renames).
- [x] Dependencies form a DAG: Unit 2 depends on Unit 1.
- [x] Every unit has at least 3 test scenarios.
- [x] No unit touches more than 6 files.
- [x] No unit introduces more than 1 new abstraction (the Podman
      package is the only new namespace; it appears in Unit 1 and is
      extended in Unit 2).
- [x] No planning-time unknowns left as blockers.
- [x] Handoff completeness: an engineer executing Unit 1 then Unit 2
      does not need to invent any product behaviour. Naming, file
      paths, return types, and call sites are spelled out.
