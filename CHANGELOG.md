# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `podctl deploy <path>` now sends a `Stack_Submission` over a CURVE DEALER socket and prints the controller's response; exit codes distinguish token errors, file errors, timeouts, and rejections (#119)
- podctl skeleton: CLIC command framework, `deploy` stub, `Podmander.Podctl.Config` with file + flag override loading (#118)

- Scheduler creates/updates service_catalog entries with agent assignment (#85)
- Get_By_Service_Id in catalog repository for lookups by service (#85)

### Removed

- `--test-config` CLI flag and `Load_Test_Deploy` from the controller; replaced by `podctl deploy` (#121)
- Obsolete `notes/spec/` document directory

### Changed

- Renamed `Podmander.CLI` package to `Podmander.Args` and files to `podmander-args.ads/adb` (#130)
- Renamed `Deploy_Command` / `Deploy_Result` to `Deployment_Command` / `Deployment_Result`; updated kind strings to `"deployment"` / `"deployment_ack"` (#126)
- ZMQ protocol migrated from positional multi-frame messages to single-frame JSON payloads with a `kind` field for dispatch (#70)
- Switched JSON library from json-ada to GNATCOLL.JSON (#107)
- service_versions table now uses service_id FK instead of service_name (#82)
- service_catalog.node_id TEXT replaced with agent_id INTEGER FK to agents.id (#79)
