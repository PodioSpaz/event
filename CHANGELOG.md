# Changelog

## [0.6.1](https://github.com/PodioSpaz/event/compare/v0.6.0...v0.6.1) (2026-07-14)


### Bug Fixes

* **app:** accept all-day due/start dates for reminders ([8704deb](https://github.com/PodioSpaz/event/commit/8704deb9d43f09f0c6e02c27bcbf2a67104b0f59)), closes [#1](https://github.com/PodioSpaz/event/issues/1)

## [0.6.0](https://github.com/PodioSpaz/event/compare/v0.5.0...v0.6.0) (2026-07-13)


### Features

* **app:** derive CLI version from git tag or commit hash ([3a2e473](https://github.com/PodioSpaz/event/commit/3a2e4735e217d0d58feecee2c486c4fbf4672210))


### Bug Fixes

* **reminders:** shift time-based alarms when due date changes ([c8bce6b](https://github.com/PodioSpaz/event/commit/c8bce6bfe077da65a9a5abe67683e08dceed7094))


### Documentation

* **skl:** document reminder continuation workflow ([464397c](https://github.com/PodioSpaz/event/commit/464397cc74012b0e1a32f704574de28521486e48))

## [0.5.0] - 2026-07-07

### Added
- Fetch script to pull the canonical AppleSyncKit worker instead of bundling it in-repo

### Changed
- Switch apple-events skill to reference the canonical sync-kit worker
- Use checksum verification in sync-from-kit.sh
- Make Homebrew formula update idempotent in CI

### Fixed
- Gracefully shut down D1SyncClient connections on exit

### Documentation
- Update worker deployment instructions and project references
- Update wrangler example configuration

## [0.4.0] - 2026-06-23

### Changed
- Extract the sync infrastructure into the shared AppleSyncKit package (encryption, D1 client, sync engine, SQLite store, config store) and depend on it as a versioned remote package
- Upgrade the Linux release Docker image to Swift 6.2

### Fixed
- Decode sync state files that predate the `dateRangeByRemoteId` field (via AppleSyncKit)
- Percent-encode `/` in record ids on delete so slash-bearing ids resolve the Worker route (via AppleSyncKit)

## [0.3.0] - 2026-06-02

### Added
- Cross-platform sync support for Linux via Cloudflare D1 SQLite
- Location-based reminders with search functionality
- Cloud sync with monotonic cursors for improved integrity
- Env-based sync configuration (EVENT_SYNC_API_URL, EVENT_SYNC_API_TOKEN, EVENT_SYNC_DEVICE_ID)
- EventSync library for HTTP client and sync state management
- Apple-events skill with integrated cloud sync
- Worker tests and migrations for Cloudflare D1
- Sync state persistence and conflict detection
- Multi-platform release builds (arm64, x86_64)

### Changed
- Make completed flag optional boolean in reminders
- Migrate Linux sync to sqlite.swift
- Refactor sync commands to unified interface (pull, push, full sync)
- Upgrade worker dependencies (Hono)
- Upgrade Linux Docker image to Swift 6.0
- ISO8601 date format for API and storage (from custom format)

### Fixed
- Sanitize shortcut service output
- Handle corrupt JSON in sync pulls
- Prevent dictionary duplicate key crashes using uniquingKeysWith
- Increase HTTP client timeout to 120s for slow networks
- Deduplicate items in SyncService
- Parse multi-pipe cursor identifiers
- Resolve compile errors in calendar event span
- Include calendar title in event ID calculation
- URL encoding in D1SyncClient delete operations

### Documentation
- Update cloud sync sequence cursor documentation
- Add deployment upgrade instructions
- Document cross-platform support
- Update apple-events skill documentation
- Add sync architecture and design documentation
- Refine Cloudflare sync design
