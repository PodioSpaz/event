# Batch 1 Sprint Contract

## Tasks

| ID | Subject | Type |
|----|---------|------|
| 001 | Package.swift 平台支持和依赖更新 | setup |
| 002 | 服务协议定义 | setup |
| 003 | EncryptedPayload 模型和加密字段容器 | setup |
| 005 | CloudflareConfig 和 ConfigService | impl |

---

## Acceptance Criteria

### Task 001: Package.swift 平台支持和依赖更新

- [ ] `swift build` exits with code 0 on macOS
- [ ] `swift package resolve | grep swift-crypto` returns swift-crypto dependency
- [ ] `Package.swift` declares Linux platform support (no `.macOS(.v14)` restriction or explicit `.linux`)
- [ ] `swift-crypto` package dependency added with version "3.0.0"
- [ ] `EventModels` target includes `Crypto` product dependency
- [ ] Existing `async-http-client` dependency unchanged

### Task 002: 服务协议定义

- [ ] `swift build` exits with code 0
- [ ] `Sources/EventModels/Protocols/RemindersBackend.swift` exists and compiles
- [ ] `Sources/EventModels/Protocols/CalendarBackend.swift` exists and compiles
- [ ] `Sources/EventModels/Protocols/ListsBackend.swift` exists and compiles
- [ ] All three protocols inherit `Sendable`
- [ ] `RemindersBackend` defines: fetchReminders, fetchReminder(byId:), createReminder, updateReminder, deleteReminder
- [ ] `CalendarBackend` defines: fetchEvents, fetchEvent(byId:), createEvent, updateEvent, deleteEvent
- [ ] `ListsBackend` defines: fetchLists, createList, deleteList, updateList
- [ ] `CreateReminderParams` and `UpdateReminderParams` structs defined in EventModels target
- [ ] `CreateEventParams` and `UpdateEventParams` structs defined in EventModels target

### Task 003: EncryptedPayload 模型和加密字段容器

- [ ] `swift build` exits with code 0
- [ ] `swift test --filter EventModelsTests` exits with code 0
- [ ] `Sources/EventModels/Models/EncryptedPayload.swift` exists
- [ ] `EncryptedPayload` struct has fields: notes, url, location, alarms, recurrenceRules, attendees (all Optional)
- [ ] `EncryptedPayload` conforms to `Codable`, `Sendable`, `Equatable`
- [ ] `EncryptedPayload` has convenience initializer with all parameters defaulting to nil
- [ ] `EncryptedPayload.isEmpty` computed property returns true when all fields are nil
- [ ] JSON encoding of `EncryptedPayload` includes all non-nil fields

### Task 005: CloudflareConfig 和 ConfigService

- [ ] `swift build` exits with code 0
- [ ] `swift test --filter EventSyncTests` exits with code 0
- [ ] `Sources/EventSync/CloudflareConfig.swift` exists
- [ ] `CloudflareConfig` struct has fields: apiURL, apiToken, deviceId
- [ ] `CloudflareConfig` conforms to `Codable`, `Sendable`, `Equatable`
- [ ] `CloudflareConfig.load()` checks environment variables first: EVENT_SYNC_API_URL, EVENT_SYNC_API_TOKEN, EVENT_SYNC_DEVICE_ID
- [ ] `CloudflareConfig.load()` throws error when only partial environment variables are set
- [ ] `CloudflareConfig.load()` falls back to `~/.config/event-sync/config.json` when no env vars
- [ ] `CloudflareConfig.save()` writes to `~/.config/event-sync/config.json` with 0o600 permissions
- [ ] `CloudflareConfig.toSyncConfig()` converts to `SyncConfig` for reuse with existing sync infrastructure

---

## Red-Green Pairs

No Red-Green pairs in this batch. All tasks are setup or standalone implementation.

---

## Evaluation Criteria Preview

The evaluator will apply the following checklist items to this batch:

| Item ID | Description |
|---------|-------------|
| CODE-VER-01 | All verification commands exit with code 0 |
| CODE-QUAL-01 | No TODO/FIXME/HACK/XXX/STUB markers in produced files |
| CODE-QUAL-02 | No stub implementations (NotImplementedError, pass-only, ellipsis-only bodies) |

---

## Sign-off

- **Generator:** executing-plans
- **Timestamp:** 2026-05-28T14:45:00Z
- **Status:** READY
- **Revision:** 0
