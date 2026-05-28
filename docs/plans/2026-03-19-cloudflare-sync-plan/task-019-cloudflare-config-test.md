# Task 019: CloudflareConfig 单元测试

**type**: test
**depends-on**: ["005"]

## BDD Scenario

```gherkin
Scenario: 从环境变量加载配置
  Given EVENT_SYNC_API_URL 和 EVENT_SYNC_API_TOKEN 环境变量已设置
  When 调用 CloudflareConfig.load()
  Then 返回配置使用环境变量的值

Scenario: 环境变量优先于 config.json
  Given config.json 存在且包含旧 URL
  And EVENT_SYNC_API_URL 环境变量已设置
  When 调用 CloudflareConfig.load()
  Then 返回环境变量中的 URL

Scenario: 仅设置部分环境变量时抛出错误
  Given 只有 EVENT_SYNC_API_URL 已设置，无 EVENT_SYNC_API_TOKEN
  When 调用 CloudflareConfig.load()
  Then 抛出配置缺失错误

Scenario: 无环境变量时回退到 config.json
  Given 无相关环境变量
  And config.json 存在且包含有效配置
  When 调用 CloudflareConfig.load()
  Then 返回 config.json 中的配置

Scenario: toSyncConfig 转换
  Given CloudflareConfig 实例
  When 调用 toSyncConfig()
  Then 返回的 SyncConfig 包含相同的 apiURL, apiToken, deviceId
```

## Files

- **Create**: `Tests/EventSyncTests/CloudflareConfigTests.swift`

## Steps

1. 创建测试类 `CloudflareConfigTests`
   - 使用 XCTest 框架
   - 在 setUp/tearDown 中设置和清理临时目录和环境变量

2. 测试用例：
   - `testLoadFromEnvironment`: 验证环境变量优先
   - `testPartialEnvironmentFails`: 验证部分环境变量报错
   - `testFallbackToConfigJSON`: 验证回退到 config.json
   - `testSaveAndLoad`: 验证 save 后 load 返回相同值
   - `testToSyncConfig`: 验证转换为 SyncConfig 正确
   - `testFilePermissions`: 验证文件权限为 0o600

## Verification

```bash
swift test --filter CloudflareConfigTests
```
