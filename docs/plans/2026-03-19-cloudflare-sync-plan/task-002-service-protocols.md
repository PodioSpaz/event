# Task 002: 服务协议定义

**type**: setup
**depends-on**: ["001"]

## BDD Scenario

```gherkin
Scenario: Commands 层通过协议访问数据 (R1, R2)
  Given RemindersBackend 协议定义了 CRUD 方法
  And CalendarBackend 协议定义了 CRUD 方法
  And ListsBackend 协议定义了列表管理方法
  When Commands 层代码引用协议类型
  Then 代码可在 macOS 和 Linux 上编译
  And 底层实现（EventKit 或 Cloudflare）在运行时注入
```

## Files

- **Create**: `Sources/EventModels/Protocols/RemindersBackend.swift`
- **Create**: `Sources/EventModels/Protocols/CalendarBackend.swift`
- **Create**: `Sources/EventModels/Protocols/ListsBackend.swift`

## Steps

1. 创建 `RemindersBackend` 协议
   - 定义方法签名：fetchReminders, fetchReminder(byId:), createReminder, updateReminder, deleteReminder
   - 继承 `Sendable`
   - 使用现有 `Reminder` 和 `ReminderList` 模型作为返回类型
   - 定义 `CreateReminderParams` 和 `UpdateReminderParams` 参数结构体

2. 创建 `CalendarBackend` 协议
   - 定义方法签名：fetchEvents, fetchEvent(byId:), createEvent, updateEvent, deleteEvent
   - 继承 `Sendable`
   - 定义 `CreateEventParams` 和 `UpdateEventParams` 参数结构体

3. 创建 `ListsBackend` 协议
   - 定义方法签名：fetchLists, createList, deleteList, updateList
   - 继承 `Sendable`

4. 所有协议放在 `EventModels` target 中（跨平台可用）

## Interface Signatures

```swift
// RemindersBackend.swift
public protocol RemindersBackend: Sendable {
    func fetchReminders(listName: String?, showCompleted: Bool) async throws -> [Reminder]
    func fetchReminder(byId id: String) async throws -> Reminder
    func createReminder(_ params: CreateReminderParams) async throws -> Reminder
    func updateReminder(id: String, params: UpdateReminderParams) async throws -> Reminder
    func deleteReminder(id: String) async throws
}

public struct CreateReminderParams: Sendable {
    public let title: String
    public let listName: String?
    public let notes: String?
    public let url: String?
    public let dueDate: String?
    public let priority: Int
    public let startDate: String?
}

public struct UpdateReminderParams: Sendable {
    public let title: String?
    public let completed: Bool?
    public let notes: String?
    public let dueDate: String?
    public let clearDue: Bool
    public let startDate: String?
    public let clearStart: Bool
    public let priority: Int?
    public let url: String?
}
```

## Verification

```bash
swift build
# 确认 EventModels target 编译成功
```
