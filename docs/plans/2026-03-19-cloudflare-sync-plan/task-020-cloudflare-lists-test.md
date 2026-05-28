# Task 020: CloudflareListService 单元测试

**type**: test
**depends-on**: ["011"]

## BDD Scenario

```gherkin
Scenario: fetchLists 调用 D1SyncClient 并返回列表
  Given MockD1SyncClient 返回 3 个 ReminderList
  When 调用 fetchLists()
  Then 返回 3 个列表

Scenario: createList 推送新列表到 D1
  Given 列表名称 "购物"
  When 调用 createList(name: "购物")
  Then 推送的 ReminderList 的 title 为 "购物"

Scenario: deleteList 调用删除 API
  Given 列表名称 "旧列表"
  When 调用 deleteList(name: "旧列表")
  Then D1SyncClient.deleteList 被调用
```

## Files

- **Create**: `Tests/EventSyncTests/CloudflareListServiceTests.swift`

## Steps

1. 复用 Task 015 的 Mock D1SyncClient

2. 测试用例：
   - `testFetchLists`: 验证 fetch 调用 pullAllLists
   - `testCreateList`: 验证 create 推送正确数据
   - `testDeleteList`: 验证 delete 调用正确 API
   - `testUpdateList`: 验证 update 推送更新

## Verification

```bash
swift test --filter CloudflareListServiceTests
```
