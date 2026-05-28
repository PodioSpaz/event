# Sprint Contract: Batch 3

## Batch Information
- **Batch Number**: 3
- **Level**: 3
- **Tasks**: 9, 10, 14, 19, 20
- **Execution Mode**: Parallel (all 5 tasks independent)

## Tasks

### Task 009: CloudflareReminderService 实现
**Type**: impl  
**Depends on**: 2 (服务协议定义), 4 (EncryptionService)  
**Status**: Pending

**BDD Scenarios**:
1. Linux 端查询任务 - D1 中有 2 条 "工作" 列表的未完成任务时，CLI 向 Workers 发起 pull 请求并解密输出
2. Linux 端创建任务 - 创建任务时加密敏感字段并推送到 D1
3. Linux 端更新任务完成状态 - 更新任务时重新加密并推送

**Implementation Requirements**:
- Create `CloudflareReminderService` actor in `Sources/EventSync/`
- Implement `RemindersBackend` protocol
- Use `D1SyncClient` for HTTP communication
- Use `EncryptionService` for encrypt/decrypt
- Implement all 5 methods: fetchReminders, fetchReminder, createReminder, updateReminder, deleteReminder

**Verification**: `swift build`

---

### Task 010: CloudflareCalendarService 实现
**Type**: impl  
**Depends on**: 2 (服务协议定义), 4 (EncryptionService)  
**Status**: Pending

**BDD Scenarios**:
1. Linux 端查询本周日历事件 - 按日期范围过滤并解密
2. Linux 端创建日历事件 - 加密敏感字段 (notes, location, attendees)
3. Linux 端查询全天事件 - 正确处理 is_all_day 标志

**Implementation Requirements**:
- Create `CloudflareCalendarService` actor in `Sources/EventSync/`
- Implement `CalendarBackend` protocol
- Use `D1SyncClient` and `EncryptionService`
- Implement all 5 methods: fetchEvents, fetchEvent, createEvent, updateEvent, deleteEvent
- Handle date range filtering and all-day events

**Verification**: `swift build`

---

### Task 014: EncryptionService 单元测试
**Type**: test  
**Depends on**: 4 (EncryptionService)  
**Status**: Pending

**BDD Scenarios**:
1. 加密后可正确解密 - 往返测试
2. IV 每次加密唯一 - 随机性验证
3. 错误密钥无法解密 - 安全性测试
4. AAD 防篡改 - recordId 不匹配时失败
5. 空 payload 处理 - 边界情况

**Test Cases**:
- `testEncryptDecryptRoundTrip`
- `testIVUniqueness`
- `testWrongKeyFails`
- `testAADMismatchFails`
- `testEmptyPayloadRoundTrip`
- `testBase64Encoding`
- `testKeyFromEnvironment`

**Implementation Requirements**:
- Create `Tests/EventSyncTests/EncryptionServiceTests.swift`
- Use XCTest framework
- Generate test keys in setUp
- Test all encryption/decryption scenarios

**Verification**: `swift test --filter EncryptionServiceTests`

---

### Task 019: CloudflareConfig 单元测试
**Type**: test  
**Depends on**: 5 (CloudflareConfig)  
**Status**: Pending

**BDD Scenarios**:
1. 从环境变量加载配置 - 优先级最高
2. 环境变量优先于 config.json - 覆盖测试
3. 仅设置部分环境变量时抛出错误 - 验证完整性检查
4. 无环境变量时回退到 config.json - 降级测试
5. toSyncConfig 转换 - 类型转换正确性

**Test Cases**:
- `testLoadFromEnvironment`
- `testPartialEnvironmentFails`
- `testFallbackToConfigJSON`
- `testSaveAndLoad`
- `testToSyncConfig`
- `testFilePermissions`

**Implementation Requirements**:
- Create `Tests/EventSyncTests/CloudflareConfigTests.swift`
- Use XCTest framework
- Set up/tear down environment variables and temp directories
- Test all configuration loading scenarios

**Verification**: `swift test --filter CloudflareConfigTests`

---

### Task 020: CloudflareListService 单元测试
**Type**: test  
**Depends on**: 11 (CloudflareListService)  
**Status**: Pending

**BDD Scenarios**:
1. fetchLists 调用 D1SyncClient 并返回列表 - 基本功能
2. createList 推送新列表到 D1 - 写入测试
3. deleteList 调用删除 API - 删除测试

**Test Cases**:
- `testFetchLists`
- `testCreateList`
- `testDeleteList`
- `testUpdateList`

**Implementation Requirements**:
- Create `Tests/EventSyncTests/CloudflareListServiceTests.swift`
- Reuse MockD1SyncClient from Task 019
- Test all CRUD operations

**Verification**: `swift test --filter CloudflareListServiceTests`

---

## Acceptance Criteria

All tasks must:
- [ ] Compile without errors (`swift build` exits 0)
- [ ] Pass all verification commands
- [ ] Have no TODO/FIXME markers
- [ ] Have no stub implementations
- [ ] Follow Swift style guide (2-space indent, 100-char line limit)
- [ ] Use proper access modifiers (public for APIs)

## Execution Strategy

1. **Phase 1**: Spawn 5 sub-agents in parallel (one per task)
   - Tasks 9, 10: Implementation tasks (Cloudflare services)
   - Tasks 14, 19, 20: Test tasks

2. **Phase 2**: Wait for all sub-agents to complete

3. **Phase 3**: Run verification commands
   - `swift build` (must exit 0)
   - `swift test --filter EncryptionServiceTests`
   - `swift test --filter CloudflareConfigTests`
   - `swift test --filter CloudflareListServiceTests`
   - `swift test` (full suite)

4. **Phase 4**: Spawn evaluator to verify code quality

5. **Phase 5**: Return structured result

## Dependencies for Next Batch (Batch 4)

After Batch 3 completes, these tasks will be unblocked:
- Task 12: CLI 命令条件编译隔离 (depends on 9, 10, 11)
- Task 13: BackendFactory 服务路由 (depends on 5, 9, 10, 11)
- Task 15: CloudflareReminderService 单元测试 (depends on 9)
- Task 16: CloudflareCalendarService 单元测试 (depends on 10)
