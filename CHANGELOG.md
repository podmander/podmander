# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Scheduler creates/updates service_catalog entries with agent assignment (#85)
- Get_By_Service_Id in catalog repository for lookups by service (#85)

### Changed

- service_versions table now uses service_id FK instead of service_name (#82)
