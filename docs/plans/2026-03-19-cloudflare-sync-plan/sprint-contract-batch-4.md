# Sprint Contract: Batch 4

## Batch Overview
- **Batch Number**: 4
- **Tasks**: 012, 013, 015, 016
- **Execution Mode**: Parallel (all tasks independent)

## Tasks

### Task 012: CLI 命令条件编译隔离
**Type**: impl  
**Depends on**: 006, 007, 008, 009, 010, 011 (all completed)  
**Status**: Pending

**BDD Scenario**:
- macOS 编译包含 EventKit 命令
- Linux 编译包含 Cloudflare 命令，不含 EventKit 代码

**Implementation Requirements**:
- Modify CLI command files to use `#if canImport(EventKit)` guards
- Commands route through BackendFactory (Task 013)
- Ensure main.swift compiles on both platforms
- Verify no EventKit references in Linux binary

**Files to Modify**:
- `Sources/event/Commands/ReminderCommands.swift`
- `Sources/event/Commands/CalendarCommands.swift`
- `Sources/event/Commands/ListCommands.swift`
- `Sources/event/Commands/SyncCommands.swift`
- `Sources/event/main.swift`

**Verification**:
```bash
swift build
```

---

### Task 013: BackendFactory 服务路由
**Type**: impl  
**Depends on**: 005, 006, 007, 008, 009, 010, 011 (all completed)  
**Status**: Pending

**BDD Scenario**:
- macOS: BackendFactory returns EventKit services (ReminderService, CalendarService, ListService)
- Linux: BackendFactory returns Cloudflare services (CloudflareReminderService, CloudflareCalendarService, CloudflareListService)

**Implementation Requirements**:
- Create `BackendFactory` with static methods
- Use `#if canImport(EventKit)` to select implementation
- Initialize D1SyncClient and EncryptionService for Linux path
- Load config from CloudflareConfig

**Files to Create**:
- `Sources/event/Services/BackendFactory.swift`

**Verification**:
```bash
swift build
```

---

### Task 015: CloudflareReminderService 单元测试
**Type**: test  
**Depends on**: 009 (completed)  
**Status**: Pending

**BDD Scenarios**:
1. fetchReminders 调用 D1SyncClient 并解密加密数据
2. createReminder 加密敏感字段后推送
3. updateReminder 合并字段并重新加密
4. deleteReminder 调用正确 API
5. 按列表名称和完成状态过滤

**Test Cases**:
- `testFetchReminders`
- `testCreateReminder`
- `testUpdateReminder`
- `testDeleteReminder`
- `testFilterByListName`
- `testFilterCompleted`

**Files to Create**:
- `Tests/EventSyncTests/CloudflareReminderServiceTests.swift`

**Verification**:
```bash
swift test --filter CloudflareReminderServiceTests
```

---

### Task 016: CloudflareCalendarService 单元测试
**Type**: test  
**Depends on**: 010 (completed)  
**Status**: Pending

**BDD Scenarios**:
1. fetchEvents 按日期范围和日历名称过滤
2. createEvent 加密 notes 和 location
3. updateEvent 重新加密敏感字段
4. deleteEvent 调用正确 API
5. 全天事件处理

**Test Cases**:
- `testFetchEventsDateRange`
- `testFetchEventsCalendarFilter`
- `testCreateEvent`
- `testUpdateEvent`
- `testDeleteEvent`
- `testAllDayEvent`

**Files to Create**:
- `Tests/EventSyncTests/CloudflareCalendarServiceTests.swift`

**Verification**:
```bash
swift test --filter CloudflareCalendarServiceTests
```

---

## Acceptance Criteria

All tasks must:
- [ ] Compile without errors
- [ ] Pass all verification commands
- [ ] Have no TODO/FIXME markers
- [ ] Have no stub implementations
- [ ] Follow Swift style guide (2-space indent, 100-char line limit)
- [ ] Use proper access modifiers (public for APIs)

Task 012 specific:
- [ ] Linux build excludes all EventKit code
- [ ] macOS build includes EventKit commands
- [ ] Commands route through BackendFactory

Task 013 specific:
- [ ] Platform selection uses `#if canImport(EventKit)`
- [ ] Linux path initializes D1SyncClient and EncryptionService
- [ ] macOS path returns EventKit services

Tasks 015 & 016 specific:
- [ ] All test cases pass
- [ ] Mock D1SyncClient used for isolation
- [ ] Encryption/decryption verified in tests

## Execution Strategy

**Phase 1**: Spawn 4 sub-agents in parallel
- Agent A: Task 012 (CLI conditional compilation)
- Agent B: Task 013 (BackendFactory)
- Agent C: Task 015 (Reminder service tests)
- Agent D: Task 016 (Calendar service tests)

**Phase 2**: Wait for all sub-agents

**Phase 3**: Run verification
- `swift build`
- `swift test --filter CloudflareReminderServiceTests`
- `swift test --filter CloudflareCalendarServiceTests`
- `swift test` (full suite)

**Phase 4**: Spawn evaluator

**Phase 5**: Return structured result

## Dependencies for Next Batch (Batch 5)

After Batch 4 completes, these tasks will be unblocked:
- Task 017: BackendFactory 路由测试 (depends on 013)
- Task 018: Linux 编译验证 (depends on 012)
