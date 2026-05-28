# Task 013: BackendFactory 服务路由

**type**: impl
**depends-on**: ["005", "006", "007", "008", "009", "010", "011"]

## BDD Scenario

```gherkin
Scenario: macOS 自动选择 EventKit Backend
  Given 运行在 macOS 平台
  When Commands 层请求 RemindersBackend
  Then BackendFactory 返回 ReminderService (EventKit)

Scenario: Linux 自动选择 Cloudflare Backend
  Given 运行在 Linux 平台
  When Commands 层请求 RemindersBackend
  Then BackendFactory 返回 CloudflareReminderService (D1)
```

## Files

- **Create**: `Sources/event/Services/BackendFactory.swift`

## Steps

1. 创建 `BackendFactory` 结构体/枚举
   - 提供静态方法创建各 Backend 实例
   - 使用 `#if canImport(EventKit)` 选择实现

2. 实现 `makeRemindersBackend()` 方法
   - macOS: 返回 `ReminderService()`
   - Linux: 返回 `CloudflareReminderService(client:encryption:)`

3. 实现 `makeCalendarBackend()` 方法
   - macOS: 返回 `CalendarService()`
   - Linux: 返回 `CloudflareCalendarService(client:encryption:)`

4. 实现 `makeListsBackend()` 方法
   - macOS: 返回 `ListService()`
   - Linux: 返回 `CloudflareListService(client:)`

5. Linux 路径需要初始化 `D1SyncClient` 和 `EncryptionService`
   - 从 `CloudflareConfig.load()` 获取配置
   - 从环境变量或配置文件加载加密密钥

## Interface Signatures

```swift
enum BackendFactory {
    static func makeRemindersBackend() async throws -> any RemindersBackend
    static func makeCalendarBackend() async throws -> any CalendarBackend
    static func makeListsBackend() async throws -> any ListsBackend

    #if os(macOS)
    /// macOS 专用：返回同步服务（用于 push/pull 命令）
    static func makeSyncService() async throws -> SyncService
    #endif
}
```

## Verification

```bash
swift build
# Task 017 提供完整测试
```
