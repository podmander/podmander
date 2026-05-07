# Agent Token Required-Argument Validation — Implementation Plan

**Issue:** [#21 — Agent startup gives misleading "Token too short" error when `--token` is missing](https://code.monospacementor.com/podmander/podmander/issues/21)
**Branch:** `21-agent-token-required`
**Status:** Draft
**Date:** 2026-05-07

## Problem Frame

`pod_agent` launched without `--token` does not validate the missing argument
at startup. The empty string flows through `Agent_Config.Join_Token`,
`Initialize` skips parsing because `Null_Unbounded_String` matches the empty
guard, and the failure surfaces deep inside CURVE setup. On the current `main`
the operator sees:

```
pod_agent: src/zsock_option.inc:2383: zsock_set_curve_serverkey:
Assertion `rc == 0 || zmq_errno () == ETERM' failed.
```

A libczmq C-level assertion is the worst possible diagnostic for "you forgot
a CLI flag." The fix moves validation to the earliest point where missing
input can be named clearly: the binary entry point, before any agent state
exists.

## Scope

**In scope:**

- `pod_agent` exits with a clear error and a usage line when `--token` is
  missing or empty.
- Same treatment when `--token=` is given with an empty value.
- Reuse of the existing unused `Podmander.CLI.Print_Usage` helper.

**Out of scope (separate issues if needed):**

- A general `--help` flag (mentioned as "ideally" in the ticket — broader
  feature, not a bug).
- Validation of other `pod_agent` arguments (`--connect`, `--name`,
  `--interval`) — they all have sensible defaults today.
- `pod_controller` — has no required arguments.
- Any change to `Podmander.CLI`'s public API beyond reusing `Print_Usage`
  (per the chosen "no new abstractions" approach).

## Approach

Inline guard in `src/bin/pod_agent.adb`. Read `--token` first; if empty,
call `Podmander.CLI.Print_Usage` and return before constructing
`Agent_Config`. No new packages, no new procedures, no new exception types.

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Where the check lives | Inline in `pod_agent.adb` | Bug touches one binary, one argument; YAGNI argues against a `Require_Argument` helper today. Revisit if a second required arg appears anywhere. |
| Fail mode | Call `Print_Usage` (sets exit status 1, logs at Critical) and `return` | Reuses existing helper; matches the package's intent; no exception machinery needed. |
| Test strategy | Manual verification only | The fix is a 3-line guard in a main procedure with no testable Ada-level seam. Subprocess-based AUnit testing was considered and rejected as out-of-proportion; explicit waiver from Jochen recorded. |
| Help feature | Deferred | Issue #21 mentions `--help` as "ideally"; outside the bug's scope. File a separate issue if wanted. |

## Implementation

### Unit 1: Guard `--token` in `pod_agent`

**Goal:** When `pod_agent` is launched without a usable `--token`, exit
cleanly with exit code 1 and a usage line, before any CZMQ or agent state
is touched.

**Requirements trace:** Resolves issue #21 in full.

**Dependencies:** None.

**Files:**

- `src/bin/pod_agent.adb` — add the guard between log-level setup and the
  `Agent_Config` aggregate. Read `--token` once, branch on empty.

**Approach:**

Insert a new declare block as a peer of the existing `Level_Str` and
`Config` blocks — between the two — that reads `--token`, calls
`Print_Usage` and returns from `Pod_Agent` when empty. The existing
`Config` aggregate is left unchanged; it re-reads `--token`, which is
guaranteed non-empty at that point.

```ada
declare
   Token : constant String := Podmander.CLI.Get ("token", "");
begin
   if Token = "" then
      Podmander.CLI.Print_Usage
        ("pod_agent --token <TOKEN> [--connect <ADDR>] "
         & "[--name <NAME>] [--interval <SEC>] [--log-level <LEVEL>]");
      return;
   end if;
end;
```

Rationale for the peer-block shape: it mirrors the `Level_Str` block at
the top of the file (read CLI value → validate → act), keeps the existing
`Config` block untouched, and re-reading `--token` once more inside the
aggregate is a trivial `Argument_Count` scan.

**Patterns:** Mirrors the structure already used for `Level_Str` validation
at the top of `Pod_Agent` (read CLI value into a local, branch on validity,
log on the bad path). Uses `Podmander.CLI.Print_Usage` — the helper exists
in the package today but is unused by any caller.

**Verification:**

Run inside `ada_dev`:

```
distrobox enter ada_dev -- alr build
distrobox enter ada_dev -- ./bin/pod_agent
distrobox enter ada_dev -- ./bin/pod_agent --token=
distrobox enter ada_dev -- ./bin/pod_agent --token PTKN-...   # known-good token
```

Expected:

- No-args and empty `--token=` invocations: exit code 1, single Critical log
  line containing `Usage: pod_agent --token <TOKEN> ...`. No CZMQ assertion.
- Known-good token: agent reaches the connect-loop as before.

Also rerun `alr test` to confirm no regressions.

**Test scenarios (manual):**

- `pod_agent` (no args) → exit 1, usage line shown
- `pod_agent --token=` → exit 1, usage line shown
- `pod_agent --token PTKN-<valid>` → behaves as today (reaches connect loop)
- `pod_agent --token=PTKN-<valid>` → same as above (equals form)

**Planning-time unknowns:** None.

## Quality Bar Checklist

- [x] Unit 1 traces to issue #21 in full.
- [x] No dependency cycles (single unit).
- [x] At least 3 verification scenarios listed.
- [x] Touches 1 file — well below the 8-file ceiling.
- [x] No new abstractions introduced (the entire point of the chosen
      approach).
- [x] No planning-time unknowns.
- [x] Handoff completeness: an engineer can execute without inventing
      product behaviour.

## Out-of-Scope Follow-ups

- Add `--help` to `pod_agent` and `pod_controller` (separate issue, not a
  bug).
- Consider whether other arguments should become required if their defaults
  ever stop being safe (e.g., if `agent-1` as a default name causes
  collisions in production).
