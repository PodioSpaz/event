# Task 005: CloudflareConfig 和 ConfigService

**type**: impl
**depends-on**: ["001"]

## BDD Scenario

```gherkin
Scenario: 首次初始化 (F-6-1)
  Given 用户首次运行 event sync init
  Then CLI 生成 AES-256 加密主密钥并存入 macOS Keychain
  And Worker URL 保存到 ~/.config/event-sync/config.json
  And 输出包含 Linux Agent 所需的三个环境变量

Scenario: 查看同步状态 (F-6-4)
  Given 用户已完成 event sync init
  When 用户运行 event sync status
  Then 输出包含 Cloudflare Workers URL 和上次同步时间
```

## Files

- **Create**: `Sources/EventSync/CloudflareConfig.swift`

## Steps

1. 创建 `CloudflareConfig` 结构体
   - 字段：apiURL, apiToken, deviceId
   - 遵循 `Codable`
   - 加载优先级：环境变量 > config.json

2. 实现 `load()` 静态方法
   - 首先检查环境变量：`EVENT_SYNC_API_URL`, `EVENT_SYNC_API_TOKEN`, `EVENT_SYNC_DEVICE_ID`
   - 如果只有部分环境变量，抛出错误
   - 回退到 `~/.config/event-sync/config.json`

3. 实现 `save()` 静态方法
   - 写入 `~/.config/event-sync/config.json`
   - 设置文件权限 0o600

4. 与现有 `SyncConfig` 整合
   - `CloudflareConfig` 可以转换为 `SyncConfig`
   - 复用 `SyncConfigStore` 的目录和文件锁机制

## Interface Signatures

```swift
public struct CloudflareConfig: Codable, Sendable, Equatable {
    public let apiURL: String
    public let apiToken: String
    public let deviceId: String

    public init(apiURL: String, apiToken: String, deviceId: String)

    /// 从环境变量或 config.json 加载配置
    public static func load() throws -> CloudflareConfig

    /// 保存配置到 config.json
    public static func save(_ config: CloudflareConfig) throws

    /// 转换为 SyncConfig（复用现有同步基础设施）
    public func toSyncConfig() -> SyncConfig
}
```

## Verification

```bash
swift build
# 通过现有 EventSyncTests 验证 SyncConfigStore 兼容性
swift test --filter EventSyncTests
```
