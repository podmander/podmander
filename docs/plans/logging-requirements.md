# Logging Facility Requirements

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-16

## Problem Frame

Controller and agent currently use bare `Ada.Text_IO.Put_Line` across 20 call sites with no log levels, no timestamps, inconsistent formatting, and no way to filter noise. Heartbeat messages fire every 30s with no toggle. The `WARNING:` prefix is applied inconsistently. As features land (task assignment, deployment, config changes), output volume will make the console unusable without structured filtering.

Since controller and agent run as systemd services, stdout is already captured by the journal. We need consistent formatting with syslog priority prefixes so journald can classify messages, and level filtering so developers and operators see appropriate detail.

## Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| R1 | Define log levels: Debug, Info, Warning, Error, Critical | Must Have | Maps to syslog priorities 7/6/4/3/2 |
| R2 | All log output goes to stdout with syslog priority prefix (`<priority>message`) | Must Have | Journald captures and classifies automatically |
| R3 | Configurable minimum log level per process | Must Have | Default: Info for production, Debug for development |
| R4 | Replace all 20 existing `Ada.Text_IO.Put_Line` call sites | Must Have | |
| R5 | Log messages include component name (e.g., `[controller]`, `[agent]`) | Should Have | Makes multi-process output readable |
| R6 | Heartbeat sent/received messages at Debug level only | Must Have | Currently spam at default output level |
| R7 | Startup information (bind address, join token, agent identity) at Info level | Must Have | |
| R8 | Warnings and errors use consistent format | Must Have | No more ad-hoc `WARNING:` prefixes |

## Success Criteria

1. `journalctl -u pod_controller -p err` shows only Error and Critical messages
2. `journalctl -u pod_agent -p warning` shows warnings and above, no heartbeat spam
3. Running directly in terminal shows human-readable output (component + level + message)
4. Setting log level to Debug shows heartbeat messages; Info hides them
5. No `Ada.Text_IO.Put_Line` calls remain in controller/agent source (only in CLI and main entry points)

## Scope Boundaries

**In scope:**
- `Podmander.Logging` package with level enum and logging procedures
- Console formatter with syslog priority prefix
- Level filtering
- Replace all existing call sites

**Out of scope:**
- Native sd_journal binding (stdout captured by journald is sufficient)
- Structured journal fields (MESSAGE_ID, custom fields)
- Log file output (journald handles persistence and rotation)
- Log aggregation across nodes

## Key Decisions

| Decision | Chosen | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| Output target | stdout with syslog priority prefix | Zero new dependencies, journald captures automatically | Native sd_journal binding (new dep to maintain), JSON structured logging (overhead) |
| Priority prefix format | `<N>message` (syslog RFC 5424) | Standard, journald parses natively | Custom prefix format, no prefix |
| Level enum | Debug/Info/Warning/Error/Critical | Matches syslog semantic, 5 levels is sufficient | 7-level syslog set (overkill), 3 levels (too coarse) |
| Log level config | CLI flag `--log-level` | Consistent with existing CLI patterns | Environment variable, config file |

## Outstanding Questions

| # | Question | Impact if Wrong | Owner |
|---|----------|-----------------|-------|
| Q1 | Should the console formatter strip the `<N>` prefix for readability when not running under systemd? | Degraded UX if we always show raw syslog prefix vs. journald missing priority if we don't emit it | Implementation decision |