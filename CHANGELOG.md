# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Version_Option` variant record in `Podmander.Controller`; `Service_Catalog_Entry.Current_Version` now uses `Version_Option` instead of a `Natural` sentinel 0 (#92)
- `Column_Is_Null` helper in `Podmander.Database` for nullable column reads

- `Podmander.Controller.Strategies` pluggable agent-selection abstraction; `First_Available` strategy extracted from Scheduler; `Schedule` gains a Strategy parameter (#137)
- `Agent_Option` variant record in `Podmander.Controller` for strategy return values (#137)

- `podctl deploy <path>` now sends a `Stack_Submission` over a CURVE DEALER socket and prints the controller's response; exit codes distinguish token errors, file errors, timeouts, and rejections (#119)
- podctl skeleton: CLIC command framework, `deploy` stub, `Podmander.Podctl.Config` with file + flag override loading (#118)

- Scheduler creates/updates service_catalog entries with agent assignment (#85)
- Get_By_Service_Id in catalog repository for lookups by service (#85)

### Removed

- Dead `Agent_Id_Type` declaration from `Podmander.Controller`; leftover from the Agent→Node refactor with no remaining references (#154)
- `Node_Id_Type` subtype alias from `Podmander.Controller`; callers now depend on `Podmander.Types` directly (#152)
- `--test-config` CLI flag and `Load_Test_Deploy` from the controller; replaced by `podctl deploy` (#121)
- Obsolete `notes/spec/` document directory

### Fixed

- Config parser now returns an error instead of silently dropping entries when `MAX_ENV_ENTRIES`, `MAX_PORTS_ENTRIES`, or `MAX_VOLUMES_ENTRIES` is exceeded, and when a port or volume string lacks a colon separator (#62)

### Changed

- Renamed transport routing identity from `node_id`/`Node_Id` to `connection_id`/`Connection_Id` across Ada types, JSON wire fields, the `agents` DB column (migration 012), and all tests (#142)
- Resolved Node-vs-Agent terminology in DOMAIN.md: a Node is the durable domain object that placement targets; an Agent is the protocol-layer process reached through it. The Service Catalog targets a Node; code alignment is tracked separately (#139)
- Renamed `Podmander.CLI` package to `Podmander.Args` and files to `podmander-args.ads/adb` (#130)
- Renamed `Deploy_Command` / `Deploy_Result` to `Deployment_Command` / `Deployment_Result`; updated kind strings to `"deployment"` / `"deployment_ack"` (#126)
- ZMQ protocol migrated from positional multi-frame messages to single-frame JSON payloads with a `kind` field for dispatch (#70)
- Switched JSON library from json-ada to GNATCOLL.JSON (#107)
- service_versions table now uses service_id FK instead of service_name (#82)
- service_catalog.node_id TEXT replaced with agent_id INTEGER FK to agents.id (#79)
