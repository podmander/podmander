# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Renamed daemon executable artifacts to `podmander-controller` and `podmander-agent` while leaving `podctl` unchanged (#181)

## [0.1.1] - 2026-06-27

### Changed

- Replaced service version env/port/volume JSON scanning with `GNATCOLL.JSON` serialization and parsing, including clear failures for malformed service JSON (#185)
- Improved controller test failure output and removed a dispatch test that covered handler absence rather than behavior (#63)
- Separated secret minting from token serialization in `Podmander.Enrollment`: `Ensure_Secret` is now the single home for minting a random secret; `Generate_Join_Token` is a pure serializer (`Config : in`, guarded by `Pre => Has_Secret`); `Bootstrap_Secret` no longer takes a `Public_Key` parameter (#173)
- Moved `Podmander.Control_Channel` out of the controller hierarchy and made it own the ROUTER socket, including listen/close setup and receive-timeout pacing; the controller no longer names CZMQ socket or poller types (#170)
- Extracted `Podmander.Controller.Enrollment_Authority` from the controller body; `Bootstrap_Certificate` and `Bootstrap_Secret` own CURVE certificate and registration-secret load/generate; `Authorize` provides the single secret-check shared by agent enrollment and Stack Submission; controller and handlers delegate all credential logic to it (#164)
- Extracted `Podmander.Controller.Control_Channel` from the controller body; it wraps the ROUTER socket behind CZMQ-free `Send`/`Receive` operations, so the Supervisor and message handlers route transport through it instead of touching the socket directly, and its no-op-on-unopened-socket replaces the per-handler `Is_Valid` guards (#163)
- Extracted `Podmander.Controller.Agent.Liveness` from the controller body; `Check_Timeouts` owns the heartbeat state machine (Registered -> Unresponsive -> Lost) and `Recover` resets agents to Unresponsive on startup; controller delegates both calls (#162)
- Extracted `Podmander.Controller.Supervisor` from the controller body; `Tick` owns the schedule-then-deploy reconciliation pass and `Recover` resets stale In_Progress catalog entries on startup; controller delegates both calls (#161)

### Added

- Documented native RPM packaging as the first distribution strategy for Podmander deliverables (#180)
- `Podmander.Agent.Atomic_File.Write` performs atomic file placement via write-then-rename, so an interrupted deploy never leaves a partial quadlet file (#69)

- `Version_Option` variant record in `Podmander.Controller`; `Service_Catalog_Entry.Current_Version` now uses `Version_Option` instead of a `Natural` sentinel 0 (#92)
- `Column_Is_Null` helper in `Podmander.Database` for nullable column reads

- `Podmander.Controller.Strategies` pluggable agent-selection abstraction; `First_Available` strategy extracted from Scheduler; `Schedule` gains a Strategy parameter (#137)
- `Agent_Option` variant record in `Podmander.Controller` for strategy return values (#137)
- `Service_Catalog_Entry.Node_Id` uses `Node_Option`; "not yet scheduled" is expressed via `Present => False` instead of a 0 sentinel (#138)

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

- Enrollment secret now generated from the kernel CSPRNG via `getrandom(2)` instead of the time-seeded `Ada.Numerics.Discrete_Random`, which had at most 32 bits of effective entropy (#174)
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
