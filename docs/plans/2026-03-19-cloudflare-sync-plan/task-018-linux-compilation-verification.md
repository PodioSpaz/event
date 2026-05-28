# Task 018: Linux 编译验证

**type**: test
**depends-on**: ["012"]

## BDD Scenario

```gherkin
Scenario: Linux 完整编译 (R3)
  Given 所有 EventKit 代码已用条件编译隔离
  When 在 Linux (Ubuntu 22.04) 上运行 swift build
  Then event 可执行文件成功生成
  And 无编译错误
  And 无 EventKit 相关警告

Scenario: Linux 编译产物可运行
  Given Linux 编译成功
  When 运行 .build/debug/event --help
  Then 输出包含所有跨平台命令
  And 不包含 macOS 专有命令 (如 sync daemon)
```

## Files

- **Create**: `scripts/verify-linux-build.sh` (辅助脚本)

## Steps

1. 创建 Linux 编译验证脚本
   - 使用 Docker 镜像 `swift:5.9-jammy`
   - 运行 `swift build`
   - 运行 `swift test --filter EventModelsTests`
   - 运行 `swift test --filter EventSyncTests`
   - 验证 `.build/debug/event --help` 输出

2. 验证项目：
   - `swift build` 无错误
   - `swift test` 跨平台测试通过
   - `event --help` 显示正确命令列表
   - 无 `import EventKit` 泄露到 Linux 编译路径

3. 确认二进制不含 EventKit 引用
   - `strings .build/debug/event | grep -i eventkit` 应无输出

## Verification

```bash
# 在 macOS 上通过 Docker 验证
docker run --rm -v $(pwd):/app -w /app swift:5.9-jammy bash -c "
  swift build &&
  swift test --filter EventModelsTests &&
  swift test --filter EventSyncTests &&
  .build/debug/event --help
"

# 确认无 EventKit 泄露
docker run --rm -v $(pwd):/app -w /app swift:5.9-jammy bash -c "
  ! grep -r 'import EventKit' Sources/EventModels Sources/EventSync &&
  echo 'PASS: No EventKit in cross-platform modules'
"
```
