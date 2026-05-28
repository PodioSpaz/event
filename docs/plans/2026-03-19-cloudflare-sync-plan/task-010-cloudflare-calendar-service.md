# Task 010: CloudflareCalendarService 实现

**type**: impl
**depends-on**: ["002", "004"]

## BDD Scenario

```gherkin
Scenario: Linux 端查询本周日历事件 (F-4-1)
  Given D1 中本周有 2 个"工作"日历的事件
  When 用户运行 event calendar list --start "2026-03-16" --end "2026-03-22"
  Then CLI 向 Workers 发起 GET /api/v1/calendar_events/pull 请求
  And 输出包含 2 个事件
  And encrypted_payload 已在本地解密，location 和 notes 可读

Scenario: Linux 端创建日历事件 (F-4-2)
  Given D1 中"工作"日历有 1 个事件
  When 用户运行 event calendar create --title "项目评审" --start "2026-03-20 14:00:00"
  Then CLI 向 Workers 发起 POST /api/v1/calendar_events/push 请求
  And 请求体中 encrypted_payload 包含加密后的 notes

Scenario: Linux 端查询全天事件 (F-4-3)
  Given D1 中有一个全天事件，is_all_day = 1
  When 用户运行 event calendar list --start "2026-03-20" --end "2026-03-20"
  Then 该事件出现在输出中
  And 日期格式为 "yyyy-MM-dd"（无时间部分）
```

## Files

- **Create**: `Sources/EventSync/CloudflareCalendarService.swift`

## Steps

1. 创建 `CloudflareCalendarService` actor
   - 依赖 `D1SyncClient` 和 `EncryptionService`
   - 遵循 `CalendarBackend` 协议

2. 实现 `fetchEvents` 方法
   - 调用 `D1SyncClient.pullAllEvents()`
   - 按日期范围和日历名称过滤
   - 解密 encrypted_payload

3. 实现 `createEvent` 方法
   - 构建 `CalendarEvent` 对象
   - 加密敏感字段 (notes, location, attendees)
   - 调用 `D1SyncClient.pushEvents()` 推送

4. 实现 `updateEvent` 和 `deleteEvent` 方法

## Interface Signatures

```swift
public actor CloudflareCalendarService: CalendarBackend {
    public init(client: D1SyncClient, encryption: EncryptionService)

    public func fetchEvents(
        from start: Date,
        to end: Date,
        calendar: String?
    ) async throws -> [CalendarEvent]

    public func createEvent(_ params: CreateEventParams) async throws -> CalendarEvent
    public func updateEvent(id: String, params: UpdateEventParams) async throws -> CalendarEvent
    public func deleteEvent(id: String) async throws
}
```

## Verification

```bash
swift build
# Task 016 提供完整测试
```
