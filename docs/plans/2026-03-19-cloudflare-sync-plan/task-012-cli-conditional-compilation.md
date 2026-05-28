# Task 012: CLI 命令条件编译隔离

**type**: impl
**depends-on**: ["006", "007", "008", "009", "010", "011"]

## BDD Scenario

```gherkin
Scenario: 同一代码库编译为 macOS 和 Linux 二进制 (R3)
  Given 所有 EventKit 代码已用 #if canImport(EventKit) 包裹
  And Commands 层通过协议访问 Backend
  When 在 macOS 上运行 swift build
  Then 编译产出包含 EventKit 命令的 event 二进制
  When 在 Linux 上运行 swift build
  Then 编译产出包含 Cloudflare 命令的 event 二进制
  And 不包含 EventKit 相关代码
```

## Files

- **Modify**: `Sources/event/Commands/ReminderCommands.swift`
- **Modify**: `Sources/event/Commands/CalendarCommands.swift`
- **Modify**: `Sources/event/Commands/ListCommands.swift`
- **Modify**: `Sources/event/Commands/SyncCommands.swift`
- **Modify**: `Sources/event/Services/SyncService.swift`
- **Modify**: `Sources/event/Services/ShortcutsService.swift`
- **Modify**: `Sources/event/Services/PermissionService.swift`
- **Modify**: `Sources/event/Extensions/*.swift` (所有 EventKit 扩展)
- **Modify**: `Sources/event/main.swift`

## Steps

1. 包裹所有 EventKit 依赖文件
   - 每个文件开头添加 `#if canImport(EventKit)`
   - 文件结尾添加 `#endif`
   - 包括：ReminderService, CalendarService, ListService, SyncService, ShortcutsService, PermissionService
   - 包括：所有 `Sources/event/Extensions/` 中的 EventKit 扩展文件

2. 更新 CLI Commands
   - `ReminderCommands.swift`: 用 `#if canImport(EventKit)` 包裹 EventKit 直接引用
   - 通过 `BackendFactory` (Task 013) 获取正确的 backend
   - 命令逻辑保持不变，只改底层数据源

3. 更新 `main.swift`
   - 确保 ArgumentParser 入口在两个平台上均可编译
   - macOS 专有命令（如 sync daemon）用条件编译包裹

4. 处理 `event` target 的 `Sources/event/` 中所有 import EventKit 引用
   - 使用 `grep -r "import EventKit" Sources/event/` 确认所有引用已隔离

## Verification

```bash
# macOS 编译
swift build

# Linux 编译（Docker）
docker run --rm -v $(pwd):/app -w /app swift:5.9-jammy swift build

# 确认 Linux 编译产物不含 EventKit 引用
docker run --rm -v $(pwd):/app -w /app swift:5.9-jammy \
  grep -r "EventKit" .build/debug/event || echo "Clean: no EventKit in Linux binary"
```
