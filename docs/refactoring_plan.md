# PM3 GUI 当前架构路线

本文档描述当前实现基线和后续路线。它不是对全部 Proxmark3 协议建立独立页面的承诺；功能优先级以可维护性、常用工作流和官方客户端兼容性为准。

## 平台与版本边界

- Windows x64 是 1.0 的主平台。
- Linux x64 是 1.0 的正式支持平台。
- Android、iOS、Web 和 macOS 不属于 1.0 的支持范围。
- PM3 GUI 不打包固件或客户端二进制文件。Windows 使用官方发行包根目录的 `pm3.bat`，Linux 使用用户安装的 `proxmark3`。
- 既有有限实机记录来自 Windows x64：使用对应 RRG commit `da509461` 的发行包和 PM3EASY512K（`PM3 GENERIC / AT91SAM7S512 / 512K`），完成 BAT 连接、提示符识别、只读 `hw version`、断开及 2026-09-05 的 Mifare 页面只读检测。它不是 PR #27 新增的实机验证，不能外推到 Linux、其他设备、写卡/擦除或完整固件交互。

## 当前架构

```text
Flutter UI / Feature
        │
        ▼
  Pm3Controller
        │
        ▼
    Pm3Backend
        │
        ▼
DesktopCliBackend
        │
        ▼
Pm3Process（内部进程适配器）
        │
        ▼
官方 Proxmark3 client
```

`Pm3Backend` 是桌面实现与上层状态/UI 之间的契约，`DesktopCliBackend` 负责把官方客户端进程映射为连接、事件和命令结果。`Pm3Process` 由后端与独立 Dart 帮助同步工具复用；`dart:io Process` 不向 Widget 或 Feature 泄漏。

### PR #27：界面语言与工具边界

界面使用 Flutter 的 ARB / `gen-l10n` 资源，提供简体中文、英语与跟随系统选项；不支持的系统语言回退为英语。`AppLocaleController` 管理当前选择、保存状态和错误，`MaterialApp` 使用生成的 delegates 与 supported locales。切换语言不重新创建连接、页面草稿或文本控制器。

`AppLocalizations` 只进入 Flutter 侧。`DesktopCliBackend` 将其适配为纯 Dart 的 `Pm3ProcessMessages`，进程层和 `tools/sync_command_catalog.dart` 不依赖 `dart:ui`；独立工具保留中文诊断默认值。运行时不翻译命令、十六进制数据或原始客户端输出。

语言偏好独立保存在应用支持目录的 `language.json` 中，`language` 为 `en`、`zh` 或 `null`（跟随系统）。写入排队、使用同目录临时文件替换，退出等待队列完成。目录查找/读写错误显示于设置页，初始化仍可完成；修复目录问题后的新选择可以重试保存，不会回退到工作目录。

导入草稿或卡片时，验证用的临时 `CommandCard` 继承当前语言，失败时不覆盖原数据。Dump 分析缓存包含语言标识；终端命令帮助随语言重新加载并丢弃过期异步结果。新增文案和语言的维护契约见 [Localization](localization.md)。

### 客户端设置

连接页负责选择并持久化串口或设备端口；设置页管理以下客户端字段：

- 客户端可执行文件路径；
- 客户端启动参数（设置页一行一个参数，内容不做 shell 分词或转义）；
- 可选工作目录。

设置以 JSON 保存于应用支持目录中的 `pm3_settings.json`。保存时先写入同目录临时文件，再原子替换目标；应用关闭等待初始化和最后一次排队写入完成，保存异常由状态层消费并显示。具体根路径由 `path_provider` 的 `getApplicationSupportDirectory()` 决定，因此随操作系统和用户账户而异，不应写死为项目目录或某个固定绝对路径。

### 本地 Session

每次成功连接创建一个本地 Session 目录：

```text
<应用支持目录>/sessions/YYYY-MM-DD_HHmmss_SSS/
├─ session.json       # 端口、客户端路径、开始/结束时间
├─ terminal.log       # 客户端输出，按行追加
└─ commands.jsonl     # 发出的命令，每行一条 JSON
```

写入通过串行队列完成。断开连接或应用关闭时，后端先完成进程退出，再关闭 Session 并等待尾部写入，从而保留可诊断的本地记录。Session 不上传网络；终端输出可能包含 UID、设备信息或命令参数等敏感内容，用户应按本机安全要求保护应用支持目录。

### 进程生命周期

连接过程会处理客户端早退和启动失败；断开时先请求客户端优雅退出，在有限等待后才强制终止，并清理 stdout/stderr 订阅和进程引用。Windows 强制退出只针对已持有的准确 PID，并终止该 PID 的进程树；POSIX 先发送 TERM，有限等待后再升级为 KILL。应用关闭等待设置写入、Session 队列、应用订阅和后端资源全部释放。

## 功能覆盖策略

GUI 专用页面只覆盖高频、稳定且能从结构化交互中获益的工作流。低频协议、诊断命令和官方客户端新增命令继续通过 Terminal 页面执行，以保留完整命令能力，避免为每个协议维护重复页面和不完整的参数封装。

当前导航按通用功能、高频（HF）、低频（LF）和工具分组；已有页面和命令映射以 `lib/ui/pages/`、`lib/services/pm3_commands.dart`、`docs/pm3_commands*.yaml` 和 `docs/pm3_commands_client.json` 为准。协议页面数量不是 1.0 的覆盖率指标。

## 下一阶段

下一阶段先建立两个可复用的注册表：

1. **Command Registry**：统一命令元数据、参数定义、能力标记和 UI 可用性。
2. **Parser Registry**：统一输出解析器、结构化结果和版本兼容策略。

注册表稳定后，再按真实使用频率扩展少量专用 GUI 页面；低频或暂未建模的命令继续保留在 Terminal。每项扩展都应保留官方客户端的透传能力，并补充相应测试和文档。

## 验证边界

在 Windows x64 工作站上执行 Dart 格式检查、Flutter 静态分析、完整 Flutter 测试和 Windows debug 构建，是桌面基础层的代码级验证。仓库的 CI 工作流还声明了 Linux x64 构建路径，但本机运行结果不能替代 Linux runner 的实际构建。

PR #27 的 CI 在 Windows/Linux 都生成并检查本地化资源，静态分析与完整测试在 Linux job 执行。语言、存储恢复、导入和界面回归测试的具体文件与限制见 [Localization](localization.md)；对先前实机记录的引用不表示本次本地化改动已重新执行全部硬件验收。

既有硬件记录仅覆盖对应 RRG commit `da509461` 的 Windows 发行包与一台 PM3EASY512K（`PM3 GENERIC / AT91SAM7S512 / 512K`）：根目录 `pm3.bat` 能够连接、输出真实提示符、执行只读 `hw version` 并断开；2026-09-05 记录还包含 Mifare 页面“检测卡片”显示 ATQA/SAK。Linux、其他设备、写卡/擦除与完整固件交互仍没有这里可引用的验收证据。
