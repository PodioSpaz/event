# Task 015: CloudflareReminderService 单元测试

**type**: test
**depends-on**: ["009"]

## BDD Scenario

```gherkin
Scenario: fetchReminders 调用 D1SyncClient 并解密
  Given MockD1SyncClient 返回 2 条加密的 Reminder
  When 调用 fetchReminders(listName: "工作")
  Then 返回 2 条解密后的 Reminder

Scenario: createReminder 加密敏感字段后推送
  Given CreateReminderParams(title: "测试", notes: "机密")
  When 调用 createReminder
  Then 推送的 Reminder 中 notes 为 nil
  And encryptedPayload 不为空
```

## Files

- **Create**: `Tests/EventSyncTests/CloudflareReminderServiceTests.swift`

## Steps

1. 创建 Mock D1SyncClient
   - 实现与 D1SyncClient 相同的公开接口
   - 返回预设的测试数据

2. 测试用例：
   - `testFetchReminders`: 验证 fetch 调用 pullAllReminders 并过滤
   - `testCreateReminder`: 验证 create 加密 notes 后推送
   - `testUpdateReminder`: 验证 update 合并字段并重新加密
   - `testDeleteReminder`: 验证 delete 调用正确 API
   - `testFilterByListName`: 验证列表名称过滤
   - `testFilterCompleted`: 验证完成状态过滤

## Verification

```bash
swift test --filter CloudflareReminderServiceTests
```
