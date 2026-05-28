# Task 016: CloudflareCalendarService 单元测试

**type**: test
**depends-on**: ["010"]

## BDD Scenario

```gherkin
Scenario: fetchEvents 调用 D1SyncClient 并按日期过滤
  Given MockD1SyncClient 返回 3 个日历事件
  When 调用 fetchEvents(from: 2026-03-16, to: 2026-03-22)
  Then 仅返回日期范围内的事件

Scenario: createEvent 加密 notes 和 location
  Given CreateEventParams(title: "会议", notes: "机密", location: "办公室")
  When 调用 createEvent
  Then 推送的 CalendarEvent 中 notes 和 location 为 nil
  And encryptedPayload 包含加密后的 notes 和 location
```

## Files

- **Create**: `Tests/EventSyncTests/CloudflareCalendarServiceTests.swift`

## Steps

1. 创建 Mock D1SyncClient (复用 Task 015 的 Mock)

2. 测试用例：
   - `testFetchEventsDateRange`: 验证日期范围过滤
   - `testFetchEventsCalendarFilter`: 验证日历名称过滤
   - `testCreateEvent`: 验证创建事件加密敏感字段
   - `testUpdateEvent`: 验证更新事件
   - `testDeleteEvent`: 验证删除事件
   - `testAllDayEvent`: 验证全天事件处理

## Verification

```bash
swift test --filter CloudflareCalendarServiceTests
```
