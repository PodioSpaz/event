# Task 009: CloudflareReminderService 实现

**type**: impl
**depends-on**: ["002", "004"]

## BDD Scenario

```gherkin
Scenario: Linux 端查询任务 (F-3-1)
  Given D1 中有 2 条 "工作" 列表的未完成任务
  When 用户运行 event reminders list --list "工作"
  Then CLI 向 Cloudflare Workers 发起 GET /api/v1/reminders/pull 请求
  And 输出包含 2 条任务
  And encrypted_payload 字段已在本地解密后呈现

Scenario: Linux 端创建任务 (F-3-2)
  Given D1 中 "工作" 列表有 2 条任务
  When 用户运行 event reminders create --title "写报告" --list "工作" --notes "机密内容"
  Then CLI 向 Cloudflare Workers 发起 POST /api/v1/reminders/push 请求
  And 请求体中的 title 字段为明文 "写报告"
  And 请求体中的 encrypted_payload 包含加密后的 notes "机密内容"
  And D1 中新增一条记录

Scenario: Linux 端更新任务完成状态 (F-3-3)
  Given D1 中存在 ID 为 "XYZ456" 的未完成任务
  When 用户运行 event reminders update --id "XYZ456" --completed
  Then CLI 向 Workers 发起 POST /api/v1/reminders/push 请求
  And D1 中该记录的 is_completed 字段更新为 1
```

## Files

- **Create**: `Sources/EventSync/CloudflareReminderService.swift`

## Steps

1. 创建 `CloudflareReminderService` actor
   - 依赖 `D1SyncClient` 进行 HTTP 通信
   - 依赖 `EncryptionService` 进行加解密
   - 遵循 `RemindersBackend` 协议

2. 实现 `fetchReminders` 方法
   - 调用 `D1SyncClient.pullAllReminders()`
   - 按 listName 过滤（如果提供）
   - 返回 `[Reminder]`

3. 实现 `createReminder` 方法
   - 构建 `Reminder` 对象
   - 提取敏感字段到 `EncryptedPayload`
   - 调用 `EncryptionService.encrypt()` 加密
   - 调用 `D1SyncClient.pushReminders()` 推送

4. 实现 `updateReminder` 方法
   - 先 fetch 现有记录
   - 合并更新字段
   - 重新加密敏感字段
   - 调用 `D1SyncClient.pushReminders()` 推送

5. 实现 `deleteReminder` 方法
   - 调用 `D1SyncClient.deleteReminder(id:)`

## Interface Signatures

```swift
public actor CloudflareReminderService: RemindersBackend {
    public init(client: D1SyncClient, encryption: EncryptionService)

    public func fetchReminders(
        listName: String?,
        showCompleted: Bool
    ) async throws -> [Reminder]

    public func createReminder(_ params: CreateReminderParams) async throws -> Reminder
    public func updateReminder(id: String, params: UpdateReminderParams) async throws -> Reminder
    public func deleteReminder(id: String) async throws
}
```

## Verification

```bash
swift build
# Task 015 提供完整测试
```
