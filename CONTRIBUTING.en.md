# Contributing Guide

Thank you for contributing improvements to PM3 GUI. The project uses the GPL-3.0 license; by submitting a contribution, you confirm that you have the right to submit the content and agree to release it under that license.

## Before You Start

- Bug reports should include the operating system, Flutter version, Proxmark3 client source, reproduction steps and sanitized logs.
- For new features or significant behavior changes, consider opening an Issue first to describe the use case and expected interaction.
- For security issues, follow [SECURITY.en.md](./SECURITY.en.md). Do not publicly disclose vulnerability details, credentials, card UIDs or private device information.

## Local Development

```bash
flutter pub get
flutter run -d windows
```

For Linux development, change the device target to `linux`. When integrating with the official Proxmark3 distribution on Windows, select `pm3.bat` in the distribution's root directory.

Before submitting, run at least the checks relevant to your changes:

```powershell
flutter gen-l10n
dart run tools\check_localizations.dart
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
```

Run `dart format` only on the Dart files changed in your contribution; do not change unrelated code to correct historical formatting. CI checks localization resources and builds the desktop application on both Windows/Linux; the full tests and static analysis run in the Linux job.

For changes to desktop packaging or platform code, also run `flutter build` for the corresponding platform. For changes involving real hardware behavior, state the device model, the scope of read-only/write operations and the actual validation results; do not describe simulated tests as successful real-device validation.

## Localization

English and Simplified Chinese resources are maintained in `lib/l10n/*.arb`.
Follow [the translation workflow](docs.en/localization.md), update both catalogs,
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

Update the corresponding HTML snapshot when changing `README.en.md` or
`docs.en/checklist_new_features.md`; regeneration instructions and document status
are in [docs.en/README.md](docs.en/README.md).

## Pull Request

- Keep changes focused, and explain the problem, solution and validation results.
- Preserve existing compatible behavior; explain the need for any new dependencies or platform differences.
- Update the affected README, CHANGELOG or architecture documentation.
- Do not commit build directories, Proxmark3 distributions, firmware, credentials or unsanitized Session logs.
