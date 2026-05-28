# Sprint Contract: Batch 2

## Batch Overview
- **Batch ID:** 2
- **Dependency Level:** 2
- **Execution Mode:** Parallel (all tasks independent)
- **Tasks:** 4, 6, 7, 8, 11

## Tasks

### Task 004: EncryptionService AES-256-GCM 实现
**Type:** impl  
**Depends on:** [3]  
**Status:** Pending

**BDD Scenarios:**
1. **S-1-1:** Encrypt notes field before storing in D1
   - Given: 用户已配置加密主密钥
   - When: 用户创建任务，notes 为 "这是机密内容"
   - Then: D1 中该任务的 notes 字段为 NULL（未明文存储）
   - And: D1 中 encrypted_payload 字段不为空
   - And: encrypted_payload 的内容无法直接读取为明文
   - And: encrypted_iv 字段包含有效的 base64 编码 IV

2. **S-1-2:** Decrypt notes field when reading from D1
   - Given: D1 中存在加密的任务（含 encrypted_payload）
   - When: 用户运行 event reminders list
   - Then: 输出中 notes 字段显示为解密后的明文
   - And: 解密使用本地主密钥

3. **S-1-3:** Report error when decryption fails with wrong key
   - Given: D1 中存在用密钥 A 加密的任务
   - When: 用户使用密钥 B 运行 event reminders list
   - Then: CLI 报告解密失败错误
   - And: 不显示损坏的数据

4. **S-1-4:** AAD prevents tampering
   - Given: D1 中存在加密任务，record_id = "T005"
   - When: 攻击者将该加密内容复制到另一条记录 record_id = "T006"
   - And: 用户尝试读取 "T006"
   - Then: 解密失败（AAD 验证不通过，因为 record_id 不匹配）

**Files:**
- Create: `Sources/EventSync/EncryptionService.swift`

**Interface:**
```swift
public actor EncryptionService {
    public init(key: SymmetricKey)
    public func encrypt(_ payload: EncryptedPayload, recordId: String, modifiedDate: String) throws -> (encryptedPayload: String, encryptedIV: String)
    public func decrypt(_ encryptedPayload: String, iv encryptedIV: String, recordId: String, modifiedDate: String) throws -> EncryptedPayload
    public static func keyFromBase64(_ base64: String) throws -> SymmetricKey
    public static func keyFromEnvironment() throws -> SymmetricKey
}
```

**Verification:**
```bash
swift build
```

---

### Task 006: Mac Reminders 协议适配
**Type:** impl  
**Depends on:** [2]  
**Status:** Pending

**BDD Scenarios:**
1. **F-1-1:** Create reminder on Mac and sync to cloud
   - Given: 云端数据库当前有 0 条任务
   - When: 用户运行 event reminders create --title "买牛奶" --list "购物"
   - Then: EventKit 中创建了一条新 Reminder
   - And: 该任务在 5 秒内同步到 Cloudflare D1

2. **F-1-2:** List reminders on Mac
   - Given: EventKit 中有 3 条 "工作" 列表的任务
   - When: 用户运行 event reminders list --list "工作"
   - Then: 输出包含所有 3 条任务
   - And: 数据来源为 EventKit（不发起 HTTP 请求）

3. **F-1-3:** Delete reminder on Mac
   - Given: EventKit 中存在 ID 为 "ABC123" 的任务
   - When: 用户运行 event reminders delete --id "ABC123"
   - Then: EventKit 中该任务被删除

**Files:**
- Modify: `Sources/event/Services/ReminderService.swift`

**Steps:**
1. 在 `ReminderService` 文件中添加 `#if canImport(EventKit)` 条件编译包裹整个文件内容
2. 添加 `RemindersBackend` 协议遵从
3. 实现协议要求的参数结构体适配（CreateReminderParams, UpdateReminderParams）
4. 确保所有 EventKit 导入在条件编译块内

**Verification:**
```bash
swift build
swift test --filter eventTests
```

---

### Task 007: Mac Calendar 协议适配
**Type:** impl  
**Depends on:** [2]  
**Status:** Pending

**BDD Scenarios:**
1. **F-2-1:** List calendar events on Mac
   - Given: Apple Calendar 中本周有 3 个事件
   - When: 用户运行 event calendar list --start "2026-03-16" --end "2026-03-22"
   - Then: 输出包含 3 个事件
   - And: 数据来源为 EventKit（不发起 HTTP 请求）

2. **F-2-2:** Create calendar event on Mac and sync
   - Given: 云端数据库当前有 0 个日历事件
   - When: 用户通过 Apple Calendar 创建一个新事件"团队会议"
   - And: Mac 端 EKEventStoreChanged 触发自动同步
   - Then: D1 calendar_events 表中新增该事件

**Files:**
- Modify: `Sources/event/Services/CalendarService.swift`

**Steps:**
1. 添加 `#if canImport(EventKit)` 条件编译包裹
2. 添加 `CalendarBackend` 协议遵从
3. 实现协议参数结构体适配（CreateEventParams, UpdateEventParams）

**Verification:**
```bash
swift build
swift test --filter eventTests
```

---

### Task 008: Mac Lists 协议适配
**Type:** impl  
**Depends on:** [2]  
**Status:** Pending

**BDD Scenarios:**
1. **List management on Mac**
   - Given: Apple Reminders 中有 3 个列表
   - When: 用户运行 event reminders lists list
   - Then: 输出包含所有 3 个列表
   - And: 数据来源为 EventKit

**Files:**
- Modify: `Sources/event/Services/ListService.swift`

**Steps:**
1. 添加 `#if canImport(EventKit)` 条件编译包裹
2. 添加 `ListsBackend` 协议遵从
3. 桥接方法签名适配协议要求

**Verification:**
```bash
swift build
swift test --filter eventTests
```

---

### Task 011: CloudflareListService 实现
**Type:** impl  
**Depends on:** [2]  
**Status:** Pending

**BDD Scenarios:**
1. **List reminders lists on Linux**
   - Given: D1 中有 3 个提醒事项列表
   - When: 用户运行 event reminders lists list
   - Then: CLI 向 Workers 发起 GET /api/v1/reminder_lists/pull 请求
   - And: 输出包含 3 个列表

**Files:**
- Create: `Sources/EventSync/CloudflareListService.swift`

**Interface:**
```swift
public actor CloudflareListService: ListsBackend {
    public init(client: D1SyncClient)
    public func fetchLists() async throws -> [ReminderList]
    public func createList(name: String, color: String?) async throws -> ReminderList
    public func deleteList(name: String) async throws
    public func updateList(id: String, name: String) async throws -> ReminderList
}
```

**Verification:**
```bash
swift build
```

---

## Acceptance Criteria

All tasks must:
- [ ] Compile successfully (`swift build` exits 0)
- [ ] Pass verification commands listed above
- [ ] Implement complete functionality (no stubs or TODOs)
- [ ] Follow Swift coding standards (2-space indent, 100-char line limit)
- [ ] Use conditional compilation `#if canImport(EventKit)` for macOS-only code
- [ ] Pass all existing tests (`swift test --filter eventTests` for Mac tasks)

## Evaluation Plan

**Evaluator:** superpowers:superpowers-evaluator  
**Checklist:** docs/retros/checklists/code-v1.md

**Key checks:**
- CODE-VER-01: All verification commands exit 0
- CODE-QUAL-01: No TODO/FIXME markers
- CODE-QUAL-02: No stub implementations
- CODE-ARCH-01: Proper protocol conformance
- CODE-ARCH-02: Conditional compilation used correctly
- CODE-SEC-01: Encryption uses AES-256-GCM with proper nonce generation
- CODE-SEC-02: AAD includes record_id and modified_date for tamper protection
