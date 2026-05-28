# Sprint Contract: Batch 5 (Final)

## Batch Overview
- **Batch Number**: 5
- **Tasks**: 017, 018
- **Execution Mode**: Parallel (both tasks independent)

## Tasks

### Task 017: BackendFactory 路由测试
**Type**: test  
**Depends on**: 013 (completed)  
**Status**: Pending

**BDD Scenarios**:
1. macOS 上返回 EventKit Backend - BackendFactory.makeRemindersBackend() 返回 ReminderService 实例
2. Linux 上返回 Cloudflare Backend - BackendFactory.makeRemindersBackend() 返回 CloudflareReminderService 实例

**Test Cases**:
- `testMakeRemindersBackend`: 验证返回正确类型
- `testMakeCalendarBackend`: 验证返回正确类型
- `testMakeListsBackend`: 验证返回正确类型
- `testLinuxConfigRequired`: Linux 路径验证配置缺失时报错

**Files to Create**:
- `Tests/eventTests/BackendFactoryTests.swift`

**Verification**:
```bash
swift test --filter BackendFactoryTests
```

---

### Task 018: Linux 编译验证
**Type**: test  
**Depends on**: 012 (completed)  
**Status**: Pending

**BDD Scenarios**:
1. Linux 完整编译 (R3) - swift build 在 Linux 上成功，无编译错误
2. Linux 编译产物可运行 - event --help 输出包含所有跨平台命令，不包含 macOS 专有命令

**Implementation Requirements**:
- Create `scripts/verify-linux-build.sh` helper script
- Use Docker image `swift:5.9-jammy` for Linux build
- Verify `swift build` exits 0
- Verify `swift test --filter EventModelsTests` passes
- Verify `swift test --filter EventSyncTests` passes
- Verify `event --help` output
- Confirm no `import EventKit` in cross-platform modules (Sources/EventModels, Sources/EventSync)
- Confirm no EventKit references in Linux binary via `strings` command

**Files to Create**:
- `scripts/verify-linux-build.sh`

**Verification**:
```bash
# Docker-based Linux build verification
docker run --rm -v $(pwd):/app -w /app swift:5.9-jammy bash -c "
  swift build &&
  swift test --filter EventModelsTests &&
  swift test --filter EventSyncTests &&
  .build/debug/event --help
"

# Confirm no EventKit leaks
docker run --rm -v $(pwd):/app -w /app swift:5.9-jammy bash -c "
  ! grep -r 'import EventKit' Sources/EventModels Sources/EventSync &&
  echo 'PASS: No EventKit in cross-platform modules'
"
```

---

## Acceptance Criteria

All tasks must:
- [ ] Compile without errors
- [ ] Pass all verification commands
- [ ] Have no TODO/FIXME markers
- [ ] Have no stub implementations
- [ ] Follow Swift style guide (2-space indent, 100-char line limit)

Task 017 specific:
- [ ] Tests use `#if canImport(EventKit)` to differentiate platform assertions
- [ ] All 4 test cases pass

Task 018 specific:
- [ ] Docker-based Linux build succeeds (swift build exits 0)
- [ ] Cross-platform tests pass on Linux (EventModelsTests, EventSyncTests)
- [ ] event --help output is correct on Linux
- [ ] No EventKit imports in EventModels or EventSync modules
- [ ] Linux binary contains no EventKit string references

## Execution Strategy

**Phase 1**: Spawn 2 sub-agents in parallel
- Agent A: Task 017 (BackendFactory tests)
- Agent B: Task 018 (Linux compilation verification via Docker)

**Phase 2**: Wait for both sub-agents

**Phase 3**: Run verification
- `swift test --filter BackendFactoryTests`
- Docker-based Linux verification

**Phase 4**: Spawn evaluator

**Phase 5**: Return structured result

## Final Batch Note

This is the last batch. After completion, all 20 tasks will be done. Phase 5 (git commit) and Phase 6 (completion summary) will follow.
