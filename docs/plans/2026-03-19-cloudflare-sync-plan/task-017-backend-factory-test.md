# Task 017: BackendFactory 路由测试

**type**: test
**depends-on**: ["013"]

## BDD Scenario

```gherkin
Scenario: macOS 上返回 EventKit Backend
  Given 编译目标为 macOS
  When 调用 BackendFactory.makeRemindersBackend()
  Then 返回 ReminderService 实例

Scenario: Linux 上返回 Cloudflare Backend
  Given 编译目标为 Linux
  When 调用 BackendFactory.makeRemindersBackend()
  Then 返回 CloudflareReminderService 实例
```

## Files

- **Create**: `Tests/eventTests/BackendFactoryTests.swift`

## Steps

1. 创建测试类 `BackendFactoryTests`
   - 使用 `#if canImport(EventKit)` 区分平台测试

2. 测试用例：
   - `testMakeRemindersBackend`: 验证返回正确类型
   - `testMakeCalendarBackend`: 验证返回正确类型
   - `testMakeListsBackend`: 验证返回正确类型
   - `testLinuxConfigRequired`: Linux 路径验证配置缺失时报错

## Verification

```bash
swift test --filter BackendFactoryTests
```
