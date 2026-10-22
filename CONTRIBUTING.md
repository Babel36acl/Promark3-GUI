# 贡献指南

感谢你为 PM3 GUI 提交改进。项目使用 GPL-3.0 许可证；提交贡献即表示你有权提交相关内容，并同意按该许可证发布。

## 开始之前

- Bug 报告请包含操作系统、Flutter 版本、Proxmark3 client 来源、复现步骤和去敏后的日志。
- 新功能或较大行为变更建议先创建 Issue，说明使用场景和预期交互。
- 安全问题请遵循 [SECURITY.md](./SECURITY.md)，不要公开漏洞细节、凭据、卡片 UID 或设备隐私信息。

## 本地开发

```bash
flutter pub get
flutter run -d windows
```

Linux 开发可将设备目标改为 `linux`。Windows 与官方 Proxmark3 发行包集成时，请选择发行包根目录的 `pm3.bat`。

提交前至少运行与改动相关的检查：

```powershell
flutter gen-l10n
dart run tools\check_localizations.dart
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
```

对本次修改的 Dart 文件单独运行 `dart format`；不要为修正历史格式而修改无关代码。CI 在 Windows/Linux 都检查本地化资源并构建桌面程序，完整测试和静态分析在 Linux job 执行。

涉及桌面打包或平台代码时，再执行对应平台的 `flutter build`。涉及真实硬件行为时，请说明设备型号、只读/写入范围和实际验证结果；不要把模拟测试写成实机通过。

## Localization

English and Simplified Chinese resources are maintained in `lib/l10n/*.arb`.
Follow [the translation workflow](docs/localization.md), update both catalogs,
and run `flutter gen-l10n` and `dart run tools/check_localizations.dart` before
the existing analysis/tests. Never edit generated localization Dart files or
translate PM3 command syntax, protocol identifiers or raw hardware output.
Use distinct keys for different meanings even if their Chinese spelling is the
same (for example, DESFire Applications versus the editor Apply action).
New temporary model instances must inherit the active localizations before
validating user data.

Keep standalone Dart tools Flutter-free: `Pm3Process` accepts
`Pm3ProcessMessages`, while `DesktopCliBackend` injects the Flutter adapter.
Changes to its Chinese defaults must continue to match the ARB catalog.
Directory lookup/storage failures must remain visible in Settings and must not
prevent startup or poison later language saves.

Relevant regression coverage lives in `test/l10n/`, `test/ui/`,
`test/models/command_card_test.dart`, `test/services/locale_settings_store_test.dart`
and `test/tools/sync_command_catalog_test.dart`. Include the exact commands and
limitations of any validation in the PR; do not claim Linux or real-device
coverage based only on Windows widget/unit tests.

Update the corresponding HTML snapshot when changing `README.md` or
`docs/checklist_new_features.md`; regeneration instructions and document status
are in [docs/README.md](docs/README.md).

## Pull Request

- 保持改动聚焦，并说明问题、解决方式和验证结果。
- 保留现有兼容行为；新增依赖或平台差异时说明必要性。
- 更新受影响的 README、CHANGELOG 或架构文档。
- 不提交构建目录、Proxmark3 发行包、固件、凭据或未脱敏 Session 日志。
