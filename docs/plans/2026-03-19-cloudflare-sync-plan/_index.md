# Cloudflare 同步架构实现计划

## Context

### 动机

当前 `event` CLI 仅能在 macOS 上运行，通过 EventKit 直接操作 Apple Reminders 和 Calendar。云端 AI Agent（运行于 Linux）无法访问同一份数据，限制了跨平台使用场景。

### 当前状态 vs 目标状态

| 维度 | 当前状态 | 目标状态 |
|------|---------|---------|
| **平台支持** | `platforms: [.macOS(.v14)]` | `platforms: [.macOS(.v14), .linux]` |
| **数据访问层** | 直接调用 EventKit Services | 协议抽象 (RemindersBackend, CalendarBackend, ListsBackend) |
| **macOS 实现** | ReminderService, CalendarService, ListService | 适配协议，添加 `extension: RemindersBackend` |
| **Linux 实现** | 无 | CloudflareReminderService, CloudflareCalendarService, CloudflareListService |
| **HTTP 客户端** | D1SyncClient (已实现 push/pull/delete) | 复用，添加 pullAll 系列方法 (已实现) |
| **加密** | 无 | EncryptionService (AES-256-GCM) + EncryptedPayload 模型 |
| **配置管理** | SyncConfigStore (已实现) | 添加 CloudflareConfig + ConfigService (Keychain/env 密钥管理) |
| **CLI 命令** | EventKit 命令 (macOS only) | 条件编译：macOS 用 EventKit，Linux 用 Cloudflare |
| **同步服务** | SyncService (macOS only) | 保持不变，仅 macOS 使用 |
| **Worker API** | skills/apple-events/references/worker/ (已实现) | 复用，无需修改 |

### 关键约束

- **EventKit 隔离**：所有 `import EventKit` 必须包裹在 `#if canImport(EventKit)` 中
- **加密密钥管理**：macOS 用 Keychain，Linux 用 `EVENT_ENCRYPTION_KEY` 环境变量
- **零运行时开销**：使用编译时条件 (`#if os(macOS)`)，不用运行时检测
- **向后兼容**：现有 macOS 功能不受影响

---

## Execution Plan

```yaml
tasks:
  - id: "001"
    subject: "Package.swift 平台支持和依赖更新"
    slug: "package-platform-support"
    type: "setup"
    depends-on: []
  - id: "002"
    subject: "服务协议定义"
    slug: "service-protocols"
    type: "setup"
    depends-on: ["001"]
  - id: "003"
    subject: "EncryptedPayload 模型和加密字段容器"
    slug: "encrypted-payload-model"
    type: "setup"
    depends-on: ["001"]
  - id: "004"
    subject: "EncryptionService AES-256-GCM 实现"
    slug: "encryption-service"
    type: "impl"
    depends-on: ["003"]
  - id: "005"
    subject: "CloudflareConfig 和 ConfigService"
    slug: "config-service"
    type: "impl"
    depends-on: ["001"]
  - id: "006"
    subject: "Mac Reminders 协议适配"
    slug: "mac-reminders-backend"
    type: "impl"
    depends-on: ["002"]
  - id: "007"
    subject: "Mac Calendar 协议适配"
    slug: "mac-calendar-backend"
    type: "impl"
    depends-on: ["002"]
  - id: "008"
    subject: "Mac Lists 协议适配"
    slug: "mac-lists-backend"
    type: "impl"
    depends-on: ["002"]
  - id: "009"
    subject: "CloudflareReminderService 实现"
    slug: "cloudflare-reminders-service"
    type: "impl"
    depends-on: ["002", "004"]
  - id: "010"
    subject: "CloudflareCalendarService 实现"
    slug: "cloudflare-calendar-service"
    type: "impl"
    depends-on: ["002", "004"]
  - id: "011"
    subject: "CloudflareListService 实现"
    slug: "cloudflare-lists-service"
    type: "impl"
    depends-on: ["002"]
  - id: "012"
    subject: "CLI 命令条件编译隔离"
    slug: "cli-conditional-compilation"
    type: "impl"
    depends-on: ["006", "007", "008", "009", "010", "011"]
  - id: "013"
    subject: "BackendFactory 服务路由"
    slug: "backend-factory"
    type: "impl"
    depends-on: ["005", "006", "007", "008", "009", "010", "011"]
  - id: "014"
    subject: "EncryptionService 单元测试"
    slug: "encryption-service-test"
    type: "test"
    depends-on: ["004"]
  - id: "015"
    subject: "CloudflareReminderService 单元测试"
    slug: "cloudflare-reminders-test"
    type: "test"
    depends-on: ["009"]
  - id: "016"
    subject: "CloudflareCalendarService 单元测试"
    slug: "cloudflare-calendar-test"
    type: "test"
    depends-on: ["010"]
  - id: "017"
    subject: "BackendFactory 路由测试"
    slug: "backend-factory-test"
    type: "test"
    depends-on: ["013"]
  - id: "018"
    subject: "Linux 编译验证"
    slug: "linux-compilation-verification"
    type: "test"
    depends-on: ["012"]
  - id: "019"
    subject: "CloudflareConfig 单元测试"
    slug: "cloudflare-config-test"
    type: "test"
    depends-on: ["005"]
  - id: "020"
    subject: "CloudflareListService 单元测试"
    slug: "cloudflare-lists-test"
    type: "test"
    depends-on: ["011"]
```

---

## Task File References

- [Task 001: Package.swift 平台支持和依赖更新](./task-001-package-platform-support.md)
- [Task 002: 服务协议定义](./task-002-service-protocols.md)
- [Task 003: EncryptedPayload 模型](./task-003-encrypted-payload-model.md)
- [Task 004: EncryptionService 实现](./task-004-encryption-service.md)
- [Task 005: ConfigService](./task-005-config-service.md)
- [Task 006: Mac Reminders Backend](./task-006-mac-reminders-backend.md)
- [Task 007: Mac Calendar Backend](./task-007-mac-calendar-backend.md)
- [Task 008: Mac Lists Backend](./task-008-mac-lists-backend.md)
- [Task 009: CloudflareReminderService](./task-009-cloudflare-reminders-service.md)
- [Task 010: CloudflareCalendarService](./task-010-cloudflare-calendar-service.md)
- [Task 011: CloudflareListService](./task-011-cloudflare-lists-service.md)
- [Task 012: CLI 条件编译](./task-012-cli-conditional-compilation.md)
- [Task 013: BackendFactory](./task-013-backend-factory.md)
- [Task 014: EncryptionService 测试](./task-014-encryption-service-test.md)
- [Task 015: CloudflareReminderService 测试](./task-015-cloudflare-reminders-test.md)
- [Task 016: CloudflareCalendarService 测试](./task-016-cloudflare-calendar-test.md)
- [Task 017: BackendFactory 测试](./task-017-backend-factory-test.md)
- [Task 018: Linux 编译验证](./task-018-linux-compilation-verification.md)
- [Task 019: CloudflareConfig 测试](./task-019-cloudflare-config-test.md)
- [Task 020: CloudflareListService 测试](./task-020-cloudflare-lists-test.md)

---

## BDD Coverage

本计划仅覆盖 **新增 Linux 跨平台支持** 所需的 BDD 场景。设计文档中的 30 个场景中，13 个由现有已发布的代码覆盖（详见下方"现有代码覆盖"）。

### 本计划新增覆盖 (17/30)

| Feature | Scenarios | Covered By |
|---------|-----------|------------|
| F-1 Mac Reminders | 3 | Task 006 (协议适配) |
| F-2 Mac Calendar | 2 | Task 007 (协议适配) |
| F-3 Linux Reminders | 3 | Task 009 (实现), Task 015 (测试) |
| F-4 Linux Calendar | 3 | Task 010 (实现), Task 016 (测试) |
| S-1 E2EE | 4 | Task 004 (实现), Task 014 (测试) |
| F-6 初始化配置 | 2/4 | Task 005 (实现), Task 019 (测试) |

### 现有代码覆盖 (13/30)

以下场景由已发布代码覆盖，无需在本计划中重复实现：

| Feature | Scenarios | Covered By (现有代码) |
|---------|-----------|---------------------|
| F-5 双向同步 | F-5-1, F-5-2 | `SyncService.pushReminders/pullReminders` — push-then-pull 完整流程已实现 |
| C-1 冲突解决 | C-1-1, C-2, C-3 | `SyncService.pullEntities` — LWW 冲突解决、tombstone-vs-edit 逻辑已实现 |
| S-3 认证 | S-3-1, S-3-2, S-3-3 | `D1SyncClient` — Bearer Token 认证、401 错误传播已实现 |
| E-2 离线操作 | E-2-1, E-2-2, E-2-3 | Mac: `SyncService` 静默失败 + `EKEventStoreChanged` 重试; Linux: `D1SyncClient` 网络错误直接抛出 |
| F-6 初始化 | F-6-2, F-6-3 | `SyncCommands` — wrangler 检查和幂等初始化已在现有 sync config 命令中实现 |

### 测试豁免 (Test Waivers)

以下 impl 任务没有独立的 test 任务配对，原因如下：

| Task | 豁免理由 |
|------|---------|
| Task 006 (Mac Reminders 协议适配) | 薄协议适配层，仅添加 `extension ReminderService: RemindersBackend {}`，底层 EventKit 服务已被现有测试覆盖 |
| Task 007 (Mac Calendar 协议适配) | 同上，`CalendarService` 薄适配 |
| Task 008 (Mac Lists 协议适配) | 同上，`ListService` 薄适配 |

这些任务的正确性通过 Task 018 (Linux 编译验证) 和 macOS 端现有 `swift test` 套件间接验证。

---

## Dependency Chain

```
Level 0:  001 (Package.swift)
            |
Level 1:  +-- 002 (Protocols)
          +-- 003 (EncryptedPayload)
          +-- 005 (ConfigService) ──── 019 (测试)
            |
Level 2:  |   +-- 004 (EncryptionService) ........... from 003
          +-- 006 (Mac Reminders)  [waiver] ......... from 002
          +-- 007 (Mac Calendar)   [waiver] ......... from 002
          +-- 008 (Mac Lists)      [waiver] ......... from 002
          +-- 011 (CF Lists) ───── 020 (测试) ....... from 002
            |
Level 3:  |   +-- 009 (CF Reminders) ── 015 (测试) .. from 002 + 004
          |   +-- 010 (CF Calendar) ─── 016 (测试) .. from 002 + 004
          |   +-- 014 (EncryptionService 测试) ...... from 004
            |
Level 4:  |   +-- 012 (CLI 条件编译) .... from 006,007,008,009,010,011
          |   +-- 013 (BackendFactory) ... from 005,006,007,008,009,010,011
            |
Level 5:      +-- 017 (BackendFactory 测试) ........ from 013
              +-- 018 (Linux 编译验证) .............. from 012
```

**关键路径**: 001 → 002 → 009/010 → 012 → 018

**并行机会**:
- Level 1: tasks 002, 003, 005 (3 parallel)
- Level 2: tasks 004, 006, 007, 008, 011 (5 parallel)
- Level 3: tasks 009, 010, 014 (3 parallel)
- Level 4: tasks 012, 013, 015, 016 (4 parallel)
- Level 5: tasks 017, 018, 019, 020 (4 parallel)

**无循环依赖**: 所有 20 个任务构成有向无环图 (DAG)，拓扑排序验证通过。

---

## Notes

### 已实现功能（无需修改）

以下功能在现有代码中已完整实现，本计划不重复：

1. **D1SyncClient** (`Sources/EventSync/D1SyncClient.swift`)
   - push/pull/delete 全量 API
   - pullAllReminders/Events/Lists (Linux 专用)
   - Bearer Token 认证
   - 批量推送和游标分页

2. **SyncService** (`Sources/event/Services/SyncService.swift`)
   - 双向同步 (push + pull)
   - LWW 冲突解决
   - 游标持久化
   - ID 映射管理

3. **SyncConfigStore** (`Sources/EventSync/SyncConfigStore.swift`)
   - config.json / cursors.json / state.json / id-mapping.json
   - 文件锁和权限 (0o600)

4. **SyncCommands** (`Sources/event/Commands/SyncCommands.swift`)
   - `event sync`, `event sync push`, `event sync pull`, `event sync status`, `event sync config`

5. **Worker API** (`skills/apple-events/references/worker/`)
   - Hono.js 路由
   - D1 Schema
   - 认证中间件

### 本计划聚焦

本计划仅实现 **Linux 跨平台支持** 所需的新增代码：

1. 协议抽象层（让 Commands 层不感知底层实现）
2. Cloudflare 服务实现（Linux 端直接操作 D1）
3. 端到端加密（E2EE）
4. 条件编译（隔离 EventKit 依赖）
5. 服务路由（BackendFactory）

### 验证策略

- **单元测试**：EncryptionService (014)、CloudflareReminderService (015)、CloudflareCalendarService (016)、BackendFactory (017)、CloudflareConfig (019)、CloudflareListService (020)
- **编译验证**：在 Linux 环境 (Docker) 中运行 `swift build` (018)
- **集成测试**：复用现有 `swift test` 套件
