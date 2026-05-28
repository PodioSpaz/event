# Task 004: EncryptionService AES-256-GCM 实现

**type**: impl
**depends-on**: ["003"]

## BDD Scenario

```gherkin
Scenario: 创建含 notes 的任务时加密存储 (S-1-1)
  Given 用户已配置加密主密钥
  When 用户创建任务，notes 为 "这是机密内容"
  Then D1 中该任务的 notes 字段为 NULL（未明文存储）
  And D1 中 encrypted_payload 字段不为空
  And encrypted_payload 的内容无法直接读取为明文
  And encrypted_iv 字段包含有效的 base64 编码 IV

Scenario: 读取任务时自动解密 (S-1-2)
  Given D1 中存在加密的任务（含 encrypted_payload）
  When 用户运行 event reminders list
  Then 输出中 notes 字段显示为解密后的明文
  And 解密使用本地主密钥

Scenario: 无法使用错误密钥解密 (S-1-3)
  Given D1 中存在用密钥 A 加密的任务
  When 用户使用密钥 B 运行 event reminders list
  Then CLI 报告解密失败错误
  And 不显示损坏的数据

Scenario: AAD 防篡改保护 (S-1-4)
  Given D1 中存在加密任务，record_id = "T005"
  When 攻击者将该加密内容复制到另一条记录 record_id = "T006"
  And 用户尝试读取 "T006"
  Then 解密失败（AAD 验证不通过，因为 record_id 不匹配）
```

## Files

- **Create**: `Sources/EventSync/EncryptionService.swift`

## Steps

1. 创建 `EncryptionService` actor
   - 使用 `#if canImport(CryptoKit)` 条件导入
   - macOS: `import CryptoKit`
   - Linux: `import Crypto`（swift-crypto）

2. 实现 `encrypt` 方法
   - 输入：EncryptedPayload, recordId, modifiedDate
   - 生成随机 12-byte IV (Nonce)
   - 构建 AAD: `"\(recordId)|\(modifiedDate)"`
   - AES-256-GCM 加密
   - 输出：base64(ciphertext + tag), base64(iv)

3. 实现 `decrypt` 方法
   - 输入：encryptedPayload (base64), encryptedIV (base64), recordId, modifiedDate
   - 验证 base64 格式
   - 从 ciphertext 分离 tag (最后 16 bytes)
   - 使用 AAD 验证并解密
   - 输出：EncryptedPayload

4. 添加密钥加载辅助方法
   - 从 base64 字符串创建 SymmetricKey
   - 从环境变量读取密钥

## Interface Signatures

```swift
public actor EncryptionService {
    public init(key: SymmetricKey)

    /// 加密 payload，返回 (encryptedPayload: String, encryptedIV: String)
    public func encrypt(
        _ payload: EncryptedPayload,
        recordId: String,
        modifiedDate: String
    ) throws -> (encryptedPayload: String, encryptedIV: String)

    /// 解密 base64 编码的密文
    public func decrypt(
        _ encryptedPayload: String,
        iv encryptedIV: String,
        recordId: String,
        modifiedDate: String
    ) throws -> EncryptedPayload

    /// 从 base64 字符串创建 SymmetricKey
    public static func keyFromBase64(_ base64: String) throws -> SymmetricKey

    /// 从环境变量 EVENT_ENCRYPTION_KEY 加载密钥
    public static func keyFromEnvironment() throws -> SymmetricKey
}
```

## Verification

```bash
swift build
# 后续 Task 014 提供完整测试
```
