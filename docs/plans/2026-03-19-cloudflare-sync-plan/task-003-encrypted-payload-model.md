# Task 003: EncryptedPayload 模型和加密字段容器

**type**: setup
**depends-on**: ["001"]

## BDD Scenario

```gherkin
Scenario: 敏感字段打包为加密容器 (S-1)
  Given EncryptedPayload 结构体定义了 notes, url, location, alarms 字段
  When 创建 EncryptedPayload 实例并编码为 JSON
  Then 输出包含所有敏感字段
  And 结构体可在 macOS 和 Linux 上编译
```

## Files

- **Create**: `Sources/EventModels/Models/EncryptedPayload.swift`

## Steps

1. 创建 `EncryptedPayload` 结构体
   - 包含可选字段：notes, url, location, alarms, recurrenceRules, attendees
   - 遵循 `Codable` 和 `Sendable`
   - 放在 `EventModels` target 中（跨平台）

2. 字段类型使用现有模型
   - `alarms: [Alarm]?`
   - `recurrenceRules: [RecurrenceRule]?`

3. 添加便捷初始化器
   - 从 `Reminder` 提取加密字段
   - 从 `CalendarEvent` 提取加密字段

## Interface Signatures

```swift
public struct EncryptedPayload: Codable, Sendable, Equatable {
    public var notes: String?
    public var url: String?
    public var location: String?
    public var alarms: [Alarm]?
    public var recurrenceRules: [RecurrenceRule]?
    public var attendees: [String]?

    public init(notes: String? = nil, url: String? = nil,
                location: String? = nil, alarms: [Alarm]? = nil,
                recurrenceRules: [RecurrenceRule]? = nil,
                attendees: [String]? = nil)

    /// 是否为空（所有字段均为 nil）
    public var isEmpty: Bool { get }
}
```

## Verification

```bash
swift build
swift test --filter EventModelsTests
```
