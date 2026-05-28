# Task 014: EncryptionService 单元测试

**type**: test
**depends-on**: ["004"]

## BDD Scenario

```gherkin
Scenario: 加密后可正确解密
  Given 使用密钥 A 初始化 EncryptionService
  When 加密 EncryptedPayload(notes: "机密") 并解密
  Then 解密结果 notes 为 "机密"

Scenario: IV 每次加密唯一
  Given 使用同一密钥加密相同 payload 两次
  Then 两次的 encrypted_iv 不同

Scenario: 错误密钥无法解密
  Given 用密钥 A 加密，用密钥 B 解密
  Then 抛出解密失败错误

Scenario: AAD 防篡改
  Given 用 recordId "T005" 加密
  When 用 recordId "T006" 解密
  Then 抛出 AAD 验证失败错误

Scenario: 空 payload 处理
  Given EncryptedPayload 所有字段均为 nil
  When 加密并解密
  Then 结果仍为空 payload
```

## Files

- **Create**: `Tests/EventSyncTests/EncryptionServiceTests.swift`

## Steps

1. 创建测试类 `EncryptionServiceTests`
   - 使用 XCTest 框架
   - 测试用密钥在 setUp 中生成

2. 测试用例：
   - `testEncryptDecryptRoundTrip`: 加密后解密还原
   - `testIVUniqueness`: 两次加密同一内容，IV 不同
   - `testWrongKeyFails`: 用错误密钥解密失败
   - `testAADMismatchFails`: recordId 不匹配导致解密失败
   - `testEmptyPayloadRoundTrip`: 空 payload 正确处理
   - `testBase64Encoding`: 输出为合法 base64 字符串
   - `testKeyFromEnvironment`: 从环境变量加载密钥

## Verification

```bash
swift test --filter EncryptionServiceTests
```
