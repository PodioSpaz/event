# Task 001: Package.swift 平台支持和依赖更新

**type**: setup
**depends-on**: []

## BDD Scenario

```gherkin
Scenario: Swift 项目可在 Linux 上编译 (R3)
  Given Package.swift 声明了 Linux 平台支持
  And swift-crypto 依赖已添加
  When 在 Linux 环境运行 swift build
  Then EventModels 和 EventSync target 编译成功
  And event executable target 编译成功（EventKit 代码被条件编译排除）
```

## Files

- **Modify**: `Package.swift`

## Steps

1. 更新 `platforms` 数组，添加 Linux 支持
   - 当前: `platforms: [.macOS(.v14)]`
   - 目标: 移除 `platforms` 限制（Swift on Linux 无需最低版本声明）或保留 macOS 限制但不在 platforms 中排除 Linux

2. 添加 `swift-crypto` 依赖
   - `.package(url: "https://github.com/apple/swift-crypto", from: "3.0.0")`

3. 为需要加密的 target 添加 `Crypto` product 依赖
   - `EventModels` target 需要 `Crypto`（用于 `EncryptedPayload` 的 `SymmetricKey`）

4. 保持现有 `async-http-client` 依赖不变（已跨平台）

## Verification

```bash
# macOS 编译验证
swift build

# 确认 swift-crypto 已解析
swift package resolve | grep swift-crypto
```
