# Task 011: CloudflareListService 实现

**type**: impl
**depends-on**: ["002"]

## BDD Scenario

```gherkin
Scenario: Linux 端查询列表
  Given D1 中有 3 个提醒事项列表
  When 用户运行 event reminders lists list
  Then CLI 向 Workers 发起 GET /api/v1/reminder_lists/pull 请求
  And 输出包含 3 个列表
```

## Files

- **Create**: `Sources/EventSync/CloudflareListService.swift`

## Steps

1. 创建 `CloudflareListService` actor
   - 依赖 `D1SyncClient`
   - 遵循 `ListsBackend` 协议
   - 列表不含敏感字段，无需加密

2. 实现 `fetchLists` 方法
   - 调用 `D1SyncClient.pullAllLists()`

3. 实现 `createList` 和 `deleteList` 方法
   - 调用 `D1SyncClient.pushLists()` 和 `deleteList()`

## Interface Signatures

```swift
public actor CloudflareListService: ListsBackend {
    public init(client: D1SyncClient)

    public func fetchLists() async throws -> [ReminderList]
    public func createList(name: String, color: String?) async throws -> ReminderList
    public func deleteList(name: String) async throws
    public func updateList(id: String, name: String) async throws -> ReminderList
}
```

## Verification

```bash
swift build
```
