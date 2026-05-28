# Task 008: Mac Lists 协议适配

**type**: impl
**depends-on**: ["002"]

## BDD Scenario

```gherkin
Scenario: 在 Mac 上查询列表
  Given Apple Reminders 中有 3 个列表
  When 用户运行 event reminders lists list
  Then 输出包含所有 3 个列表
  And 数据来源为 EventKit
```

## Files

- **Modify**: `Sources/event/Services/ListService.swift`

## Steps

1. 添加 `#if canImport(EventKit)` 条件编译包裹

2. 添加 `ListsBackend` 协议遵从
   - `extension ListService: ListsBackend {}`

3. 桥接方法签名适配协议要求

## Verification

```bash
swift build
swift test --filter eventTests
```
