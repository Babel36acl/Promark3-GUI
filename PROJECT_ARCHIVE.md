# PM3 GUI 项目存档 — 开发笔记
> 创建时间: 2026-04-08 | 此文件记录项目开发上下文，便于后续接手

> **历史快照，不是当前功能清单。** 下文保留 2026-04-08 的目录、平台、
> 完成状态与环境记录；当前开发请以 [README](README.md)、
> [架构现状](docs/refactoring_plan.md) 和 [本地化指南](docs/localization.md) 为准。

## PR #27 后的当前补充（2026-10-22）

- 现有导航包含 30 个页面，界面支持简体中文和英语，不再硬编码为仅中文；ARB
  与生成流程位于 `lib/l10n/`，当前每种语言 701 条消息。
- 语言可立即切换并独立保存于 `language.json`；导入验证、命令帮助和 Dump
  分析按所选语言工作。目录查找/保存失败会在设置页提示，后续保存可重试。
- `Pm3Process` 当前位于 `lib/backend/desktop_cli/`，通过纯 Dart 消息契约支持独立
  命令帮助同步；Flutter 本地化适配保留在后端边界。
- 正式桌面范围是 Windows/Linux x64。下文 Android、主题和待完成条目只代表历史记录；
  不能据此推断当前支持范围或重新声称已经完成实机验证。

---

## 项目状态总结（历史记录）

- ✅ Flutter 项目创建完成，所有 19 个 Dart 源文件（3198 行）
- ✅ 界面全中文本地化
- ✅ Linux 构建验证通过
- ✅ Android USB OTG 配置完成
- ✅ Git 仓库（2 次提交）
- ⚠️ 未在有显示器的环境实际运行过（远程无头环境缺 GPU 驱动）

## 架构

**CLI Wrapper** — GUI 不直接实现 PM3 硬件协议，而是通过 `dart:io Process` 启动 PM3 命令行并交互。

```
用户操作 → AppState → PM3Process.sendCommand(stdin)
                          ↓
                     PM3 CLI stdout → OutputParser (正则)
                          ↓
                     结构化数据 → notifyListeners → UI
```

**优势**: PM3 固件/CLI 更新不影响 GUI 兼容性

## 代码导航

| 功能 | 入口文件 | 说明 |
|------|----------|------|
| 应用启动 | `lib/main.dart` | Provider 注入 |
| 全局状态 | `lib/state/app_state.dart` | 连接/终端/卡片/主题 |
| PM3 通信 | `lib/services/pm3_process.dart` | Process 管道 |
| 命令模板 | `lib/services/pm3_commands.dart` | 所有 PM3 命令 |
| 输出解析 | `lib/parsers/output_parser.dart` | UID/ATQA/SAK/块/密钥 正则 |
| 转储解析 | `lib/parsers/dump_parser.dart` | .eml/.bin/.json 自动识别 |
| 数据模型 | `lib/models/mifare_card.dart` | CardType + MifareCard |
| 访问控制 | `lib/models/access_bits.dart` | 访问位解码 |
| 主页导航 | `lib/ui/home_page.dart` | 底部 6 页导航 |
| 主题 | `lib/ui/theme.dart` | Material 3 深/浅色 |

## 功能页面

1. **连接** — PM3 路径 + 串口选择 + 连接状态
2. **终端** — 全功能终端 + 7 个快捷按钮
3. **Dump 查看器** — 打开/查看/导出 MIFARE 转储文件
4. **高频 (Mifare)** — 检测/攻击/读写/魔术卡 (4 选项卡)
5. **低频** — 通用/EM4x05/T55xx (3 选项卡)
6. **设置** — 主题/路径/关于/维护

## 待完成

- 信号波形可视化（fl_chart 已引入未使用）
- 转储文件编辑功能
- iClass / Legic / NTAG / DESFire 页面
- 命令自动补全 + 历史持久化
- 国际化框架（当前硬编码中文，未用 arb 文件）
- 单元测试
- Windows/Android 实际测试

## 环境要求

```bash
# Flutter
export PATH="/opt/flutter/bin:$PATH"
flutter pub get

# Linux 构建依赖
pacman -S gtk3  # Arch

# 构建
flutter build linux    # 输出 build/linux/x64/release/bundle/
flutter build apk      # Android

# 运行
flutter run -d linux
```

## 注意事项

- 全局 gitignore (`~/.gitignore_global`) 可能排除 `lib/`，项目 `.gitignore` 末尾有 `!/lib/` 覆盖
- Android USB OTG 配置在 `android/app/src/main/AndroidManifest.xml` 和 `xml/usb_device_filter.xml`
- PM3 VID:PID = `9ac4:4b8f`

## 参考

- [wh201906/Proxmark3GUI](https://github.com/wh201906/Proxmark3GUI) — Qt C++ 参考实现
- [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) — PM3 固件/CLI
