# Task 006: Mac Reminders 协议适配

**type**: impl
**depends-on**: ["002"]

## BDD Scenario

```gherkin
Scenario: 在 Mac 上创建任务后同步到云端 (F-1-1)
  Given 云端数据库当前有 0 条任务
  When 用户运行 event reminders create --title "买牛奶" --list "购物"
  Then EventKit 中创建了一条新 Reminder
  And 该任务在 5 秒内同步到 Cloudflare D1

Scenario: 在 Mac 上查询任务 (F-1-2)
  Given EventKit 中有 3 条 "工作" 列表的任务
  When 用户运行 event reminders list --list "工作"
  Then 输出包含所有 3 条任务
  And 数据来源为 EventKit（不发起 HTTP 请求）

Scenario: 在 Mac 上删除任务 (F-1-3)
  Given EventKit 中存在 ID 为 "ABC123" 的任务
  When 用户运行 event reminders delete --id "ABC123"
  Then EventKit 中该任务被删除
```

## Files

- **Modify**: `Sources/event/Services/ReminderService.swift`

## Steps

1. 在 `ReminderService` 文件中添加 `#if canImport(EventKit)` 条件编译包裹整个文件内容

2. 添加 `RemindersBackend` 协议遵从
   - `extension ReminderService: RemindersBackend {}`
   - 确认现有方法签名是否匹配协议要求
   - 如有差异，添加桥接方法

3. 实现协议要求的参数结构体适配
   - `createReminder(_ params: CreateReminderParams)` → 调用现有 `createReminder(title:listName:...)`
   - `updateReminder(id: params: UpdateReminderParams)` → 调用现有 `updateReminder(id:title:...)`

4. 确保所有 EventKit 导入在条件编译块内

## Verification

```bash
# macOS 编译验证
swift build
# 运行现有测试
swift test --filter eventTests
```
