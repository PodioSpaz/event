# Task 007: Mac Calendar 协议适配

**type**: impl
**depends-on**: ["002"]

## BDD Scenario

```gherkin
Scenario: 在 Mac 上查询日历事件 (F-2-1)
  Given Apple Calendar 中本周有 3 个事件
  When 用户运行 event calendar list --start "2026-03-16" --end "2026-03-22"
  Then 输出包含 3 个事件
  And 数据来源为 EventKit（不发起 HTTP 请求）

Scenario: 在 Mac 上创建日历事件后同步 (F-2-2)
  Given 云端数据库当前有 0 个日历事件
  When 用户通过 Apple Calendar 创建一个新事件"团队会议"
  And Mac 端 EKEventStoreChanged 触发自动同步
  Then D1 calendar_events 表中新增该事件
```

## Files

- **Modify**: `Sources/event/Services/CalendarService.swift`

## Steps

1. 添加 `#if canImport(EventKit)` 条件编译包裹

2. 添加 `CalendarBackend` 协议遵从
   - `extension CalendarService: CalendarBackend {}`
   - 桥接方法签名适配协议要求

3. 实现协议参数结构体适配
   - `createEvent(_ params: CreateEventParams)` → 调用现有 `createEvent(...)`
   - `updateEvent(id: params: UpdateEventParams)` → 调用现有 `updateEvent(...)`

## Verification

```bash
swift build
swift test --filter eventTests
```
