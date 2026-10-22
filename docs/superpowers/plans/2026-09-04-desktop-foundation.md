# PM3 Desktop Foundation 实现计划

> **历史实现计划（2026-09-04）。** 下文步骤与执行说明记录当时的开发过程，
> 不是当前代理应直接执行的新指令。PR #27 的语言状态、独立 Dart 工具边界和
> 存储恢复契约见 [Localization](../../localization.md)；当前开发流程以
> [CONTRIBUTING](../../../CONTRIBUTING.md) 为准。

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在已完成的 `Pm3Backend` 边界上补齐 Windows/Linux 客户端配置持久化、本地 Session 日志和可靠进程退出，使 Phase 2 形成可运行、可测试的桌面基础层。

**架构：** 配置与 Session 都是桌面本地能力，通过小型服务注入 `ConnectionState`/`AppState`，不进入 Feature 或 Widget 的进程细节。`Pm3Process` 继续是 `DesktopCliBackend` 的内部适配器，但明确拥有 stdout/stderr 订阅、退出握手和 dispose 生命周期。所有新文件写入都限定在应用支持目录，不联网、不记录密钥库凭据。

**技术栈：** Flutter Desktop、Dart `dart:io`/`dart:convert`、Provider、`path_provider`、`file_selector`、`flutter_test`。

---

## 文件结构

- 创建 `lib/core/pm3/pm3_client_settings.dart`：可序列化的桌面客户端设置。
- 创建 `lib/services/pm3_settings_store.dart`：JSON 设置文件的加载、校验与保存。
- 修改 `lib/state/connection_state.dart`：加载/保存客户端路径、工作目录、参数和串口。
- 修改 `lib/state/app_state.dart`：暴露初始化状态和设置操作。
- 修改 `lib/ui/pages/settings_page.dart`、`lib/ui/pages/connection_page.dart`：提供真实文件选择和设置状态反馈。
- 创建 `lib/core/pm3/pm3_session.dart`：Session 元数据和命令记录模型。
- 创建 `lib/services/pm3_session_recorder.dart`：写入 `session.json`、`terminal.log`、`commands.jsonl`。
- 修改 `lib/core/pm3/pm3_controller.dart`、`lib/state/app_state.dart`：把命令与后端事件接入 Session。
- 修改 `lib/backend/desktop_cli/pm3_process.dart`：可靠处理早退、优雅退出、强制终止与 dispose。
- 修改 `lib/backend/desktop_cli/desktop_cli_backend.dart`：等待底层关闭并保证订阅释放顺序。
- 创建 `test/services/pm3_settings_store_test.dart`、`test/services/pm3_session_recorder_test.dart`、`test/backend/pm3_process_test.dart`。
- 修改 `README.md`、`docs/refactoring_plan.md`：同步 Windows/Linux-only 与 Phase 2 现状。

### 任务 1：客户端设置持久化与路径选择

**文件：**
- 创建：`lib/core/pm3/pm3_client_settings.dart`
- 创建：`lib/services/pm3_settings_store.dart`
- 修改：`lib/state/connection_state.dart`
- 修改：`lib/state/app_state.dart`
- 修改：`lib/ui/pages/settings_page.dart`
- 修改：`lib/ui/pages/connection_page.dart`
- 测试：`test/services/pm3_settings_store_test.dart`
- 测试：`test/state/connection_state_test.dart`

- [x] **步骤 1：编写失败的设置存储测试**

```dart
test('round-trips desktop client settings', () async {
  final directory = await Directory.systemTemp.createTemp('pm3-settings-');
  addTearDown(() => directory.delete(recursive: true));
  final store = Pm3SettingsStore(directoryProvider: () async => directory);
  const expected = Pm3ClientSettings(
    executable: r'C:\tools\proxmark3.exe',
    port: 'COM7',
    arguments: ['--flush'],
    workingDirectory: r'C:\tools',
  );
  await store.save(expected);
  expect(await store.load(), expected);
});

test('invalid JSON falls back without throwing', () async {
  // 写入无效 JSON 后，load() 返回 null，不让应用启动失败。
});
```

- [x] **步骤 2：运行红灯测试**

运行：`flutter test --no-pub test/services/pm3_settings_store_test.dart`

预期：FAIL，缺少 `Pm3ClientSettings` 和 `Pm3SettingsStore`。

- [x] **步骤 3：实现最小模型与存储**

```dart
final class Pm3ClientSettings {
  const Pm3ClientSettings({
    required this.executable,
    this.port = '',
    this.arguments = const [],
    this.workingDirectory,
  });

  final String executable;
  final String port;
  final List<String> arguments;
  final String? workingDirectory;

  Map<String, Object?> toJson() => <String, Object?>{
        'executable': executable,
        'port': port,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
      };
}
```

`Pm3SettingsStore` 使用注入的目录提供器，将 JSON 保存为 `pm3_settings.json`；`load()` 对缺失、无效 JSON、错误字段返回 `null`。

- [x] **步骤 4：把设置接入状态层和 UI**

`ConnectionState.initialize()` 在启动时恢复设置；`setPm3Path`、`setPort` 和新的参数/工作目录 setter 保存快照。设置页与连接页使用 `FileDialogService.pickSingleFilePath()` 选择 `proxmark3.exe`/`proxmark3`，不再要求用户只能手输路径。

- [x] **步骤 5：运行绿灯和相关回归测试**

运行：

```text
flutter test --no-pub test/services/pm3_settings_store_test.dart test/state/connection_state_test.dart
flutter test --no-pub
```

预期：全部通过。

- [x] **步骤 6：Commit**

```text
feat(配置): 持久化 PM3 客户端设置
```

### 任务 2：本地 Session 与统一日志

**文件：**
- 创建：`lib/core/pm3/pm3_session.dart`
- 创建：`lib/services/pm3_session_recorder.dart`
- 修改：`lib/core/pm3/pm3_controller.dart`
- 修改：`lib/state/app_state.dart`
- 测试：`test/services/pm3_session_recorder_test.dart`
- 测试：`test/backend/pm3_controller_test.dart`

- [x] **步骤 1：编写失败的 Session 测试**

```dart
test('records metadata, terminal output and command history', () async {
  final directory = await Directory.systemTemp.createTemp('pm3-session-');
  addTearDown(() => directory.delete(recursive: true));
  final recorder = Pm3SessionRecorder(rootDirectoryProvider: () async => directory);
  await recorder.start(devicePort: 'COM7', executable: 'proxmark3.exe');
  await recorder.recordCommand('hw version');
  await recorder.recordOutput('[+] client: v4');
  await recorder.close();
  expect(await File('${recorder.sessionPath}/session.json').exists(), isTrue);
  expect(await File('${recorder.sessionPath}/terminal.log').readAsString(), contains('client: v4'));
  expect(await File('${recorder.sessionPath}/commands.jsonl').readAsString(), contains('hw version'));
});
```

- [x] **步骤 2：运行红灯测试**

运行：`flutter test --no-pub test/services/pm3_session_recorder_test.dart`

预期：FAIL，Session 类型和记录器不存在。

- [x] **步骤 3：实现串行写入的 Session 记录器**

每次成功连接创建 `sessions/YYYY-MM-DD_HHmmss_SSS/`，立即写 `session.json`。所有输出追加到 `terminal.log`，所有命令以单行 JSON 追加到 `commands.jsonl`。写操作通过内部 Future 链串行化；`close()` 等待尾部写入并在元数据中写入 `endedAt`。

- [x] **步骤 4：接入控制器和应用状态**

`Pm3Controller.execute()` 在调用后端前发出命令观察点；`AppState` 在 connected 时启动 Session，在 output 事件时记录输出，在 disconnected/dispose 时关闭。记录失败只更新本地可诊断状态，不阻断 PM3 命令。

- [x] **步骤 5：运行绿灯和相关回归测试**

运行：

```text
flutter test --no-pub test/services/pm3_session_recorder_test.dart test/backend/pm3_controller_test.dart
flutter test --no-pub
```

预期：全部通过，并证明 close 后文件内容完整。

- [x] **步骤 6：Commit**

```text
feat(日志): 添加本地 PM3 Session 记录
```

### 任务 3：可靠的 PM3 进程生命周期

**文件：**
- 修改：`lib/backend/desktop_cli/pm3_process.dart`
- 修改：`lib/backend/desktop_cli/desktop_cli_backend.dart`
- 测试：`test/backend/pm3_process_test.dart`

- [x] **步骤 1：编写失败的进程生命周期测试**

测试运行时创建一个 Dart 子进程 fixture：启动后打印 `pm3 -->`，收到 `quit` 后退出；另一个 fixture 在输出提示符前直接退出。

```dart
test('disconnect waits for a graceful child exit', () async {
  final process = Pm3Process(connectCooldown: Duration.zero);
  expect(await process.connect(dartExecutable, 'COM7', arguments: fixtureArgs), isTrue);
  await process.disconnect();
  expect(process.state, Pm3ProcessState.disconnected);
});

test('connect returns false when child exits before prompt', () async {
  final process = Pm3Process(connectCooldown: Duration.zero);
  expect(await process.connect(dartExecutable, 'COM7', arguments: earlyExitArgs), isFalse);
  expect(process.lastError, contains('退出'));
});
```

- [x] **步骤 2：运行红灯测试**

运行：`flutter test --no-pub test/backend/pm3_process_test.dart`

预期：FAIL；现有构造器不可注入 cooldown，且早退连接等待到 15 秒超时。

- [x] **步骤 3：实现最小生命周期修复**

保存 stdout/stderr 订阅；早退时完成连接 Future；`disconnect()` 先写 `quit` 并等待有限时间，超时才 `kill()`；清理订阅和进程引用后再发送 disconnected；`dispose()` 标记已释放并保证后续异步回调不向关闭的 controller 写入。

- [x] **步骤 4：运行绿灯和相关回归测试**

运行：

```text
flutter test --no-pub test/backend/pm3_process_test.dart
flutter test --no-pub
```

预期：全部通过，测试进程无残留。

- [x] **步骤 5：Commit**

```text
fix(后端): 完善 PM3 进程退出生命周期
```

### 任务 4：文档、静态检查和桌面构建验证

**文件：**
- 修改：`README.md`
- 修改：`docs/refactoring_plan.md`

- [x] **步骤 1：同步设计基线**

明确 Windows x64 为主平台、Linux x64 正式支持；Android/macOS/Web 不属于 1.0。记录外部 client 设置、本地 Session 文件、后端生命周期和下一阶段 Command/Parser 工作。

- [x] **步骤 2：格式化与静态检查**

运行：

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
```

预期：改动文件格式正确；分析不得新增 warning/error。仓库既有 `tools/verify_extract.dart` 4 条 `avoid_print` info 单独报告。

- [x] **步骤 3：完整测试与 Windows 构建**

运行：

```text
flutter test --no-pub
flutter build windows --debug --no-pub
```

预期：测试 0 失败；Windows debug 构建退出码 0。Linux 构建需要 Linux 主机，当前 Windows 只做代码路径与 CI 配置静态核查。

- [x] **步骤 4：Commit**

```text
docs(架构): 更新桌面基础层实施状态
```

### 任务 5：RRG Windows BAT 客户端兼容与实机复核

**文件：**
- 修改：`lib/backend/desktop_cli/pm3_process.dart`
- 修改：`lib/backend/desktop_cli/desktop_cli_backend.dart`
- 修改：`lib/state/connection_state.dart`
- 修改：`lib/ui/pages/connection_page.dart`
- 修改：`lib/ui/pages/settings_page.dart`
- 新增：`test/backend/desktop_cli_backend_test.dart`
- 修改：`test/backend/pm3_process_test.dart`
- 修改：`test/state/connection_state_test.dart`
- 修改：`README.md`
- 修改：`docs/refactoring_plan.md`

- [x] **步骤 1：为 BAT 启动入口编写失败测试**

在 Windows 上选择 `pm3.bat` 时，进程层必须经 `cmd.exe /d /c call` 启动该脚本，并让 stdin/stdout 保持可交互；不得把“正在建立 USB 通信”的中间信息误判为已连接提示。

- [x] **步骤 2：运行红灯测试**

运行：`flutter test --no-pub test/backend/pm3_process_test.dart`

预期：FAIL；现有实现会直接把 `.bat` 交给 `Process.start`，且过早接受 `Communicating with PM3 over USB-CDC`。

实际红灯还覆盖了 RRG BAT 在 stdout 管道下不刷新等待输入的提示符：没有主动输入时连接超时；单独 `[usb]` transport 标签也不得成为成功证据。

- [x] **步骤 3：实现最小 BAT 适配**

仅 Windows 的 `.bat`/`.cmd` 入口通过系统命令解释器启动；原生 `proxmark3.exe` 与 Linux `proxmark3` 路径保持原行为。Windows BAT 首次报告 USB-CDC 通信后发送一次只读 `hw version` 握手以推动管道输出，并支持识别跨 chunk、无末尾换行的真实 `pm3 -->`；通信中间行或单独 transport 标签不视为连接成功。设置页和默认路径说明优先引导 Windows 用户选择发行包根目录的 `pm3.bat`。

- [x] **步骤 4：实机与回归验证**

Windows x64 使用用户提供、对应 RRG commit `da509461` 的发行包和 PM3EASY512K（`PM3 GENERIC / AT91SAM7S512 / 512K`）完成根目录 `pm3.bat` 链路连接、真实提示符识别、只读 `hw version` 和断开。该证据不覆盖 Linux、其他设备、完整固件交互或真实卡片操作。完整 Flutter 测试、改动范围静态检查和 Windows debug 构建通过。

- [x] **步骤 5：Commit**

```text
2cc4242 feat(后端): 兼容官方 Windows PM3 脚本
36452ec fix(后端): 识别无换行 PM3 提示符
471dfa6 fix(后端): 唤醒 Windows BAT 交互提示
```
