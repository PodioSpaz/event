# Handoff Summary: Batch 3

## Completed Tasks

| ID | Subject | Checklist Result | Batch |
|----|---------|------------------|-------|
| 009 | CloudflareReminderService 实现 | PASS (all items) | 3 |
| 010 | CloudflareCalendarService 实现 | PASS (all items) | 3 |
| 014 | EncryptionService 单元测试 | PASS (all items) | 3 |
| 019 | CloudflareConfig 单元测试 | PASS (all items) | 3 |
| 020 | CloudflareListService 单元测试 | PASS (all items) | 3 |

## Remaining Tasks

| ID | Subject | Status | Dependencies |
|----|---------|--------|--------------|
| 012 | CLI 命令条件编译隔离 | pending | 006, 007, 008, 009, 010, 011 |
| 013 | BackendFactory 服务路由 | pending | 005, 006, 007, 008, 009, 010, 011 |
| 015 | CloudflareReminderService 单元测试 | pending | 009 |
| 016 | CloudflareCalendarService 单元测试 | pending | 010 |
| 017 | BackendFactory 路由测试 | pending | 013 |
| 018 | Linux 编译验证 | pending | 012 |

## Key Decisions

- **EncryptedCarrier pattern**: Encrypted data is stored as a JSON carrier `{"v":1,"p":"...","i":"..."}` in the `notes` field of Reminder/CalendarEvent models. This avoids modifying the shared domain models while enabling end-to-end encryption through the existing `D1SyncClient` pipeline.

- **D1Client protocol**: Introduced `D1Client` protocol to enable test mock injection without changing the external API. `D1SyncClient` conforms via an unconditional extension. Cloudflare services accept `D1Client` instead of the concrete type.

- **Graceful degradation**: When pulling data, if `notes` is not a valid EncryptedCarrier (e.g., plain text from a Mac client), the service returns the Reminder/CalendarEvent as-is without attempting decryption.

- **EncryptionService bug fix**: Fixed nonce handling in `decrypt()` method. The `combined` format from `AES.GCM.seal()` is `nonce || ciphertext || tag`, so decrypt must strip the 12-byte nonce prefix before stripping the 16-byte tag.

- **Internal visibility for testing**: Changed `CloudflareConfig.loadFromEnvironment` from `private` to `internal` to enable direct unit testing.

## File Ownership

| File Path | Last Modified By Task |
|-----------|-----------------------|
| Sources/EventSync/CloudflareReminderService.swift | 009 |
| Sources/EventSync/CloudflareCalendarService.swift | 010 |
| Sources/EventSync/D1Client.swift | 009 |
| Sources/EventSync/D1SyncClient.swift | 009 |
| Sources/EventSync/CloudflareListService.swift | 020 |
| Sources/EventSync/CloudflareConfig.swift | 019 |
| Sources/EventSync/EncryptionService.swift | 014 |
| Tests/EventSyncTests/EncryptionServiceTests.swift | 014 |
| Tests/EventSyncTests/CloudflareConfigTests.swift | 019 |
| Tests/EventSyncTests/CloudflareListServiceTests.swift | 020 |

## Blockers

None.
