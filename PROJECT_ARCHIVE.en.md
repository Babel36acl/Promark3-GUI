# PM3 GUI Project Archive — Development Notes
> Created: 2026-04-08 | This file records the project's development context to help future maintainers take over.

> **Historical snapshot, not a current feature list.** The directories, platforms,
> completion status and environment notes below are preserved from 2026-04-08;
> for current development, refer to the [README](README.en.md),
> [current architecture](docs.en/refactoring_plan.md) and [localization guide](docs.en/localization.md).

## Current Addendum After PR #27 (2026-10-22)

- The existing navigation contains 30 pages, and the interface supports Simplified Chinese and English rather than
  being hard-coded for Chinese only; ARB resources and generation are in `lib/l10n/`, with 701 messages per language.
- The language can be switched immediately and is saved independently in `language.json`; import validation,
  command help and Dump analysis use the selected language. Directory lookup/save failures appear in Settings,
  and later saves can be retried.
- `Pm3Process` is now in `lib/backend/desktop_cli/`, supporting standalone command-help
  synchronization through a pure Dart message contract; Flutter localization adaptation stays at the backend boundary.
- The officially supported desktop scope is Windows/Linux x64. Android, themes and unfinished items below are
  historical records only; do not infer the current support scope or make renewed claims of completed real-device validation from them.

---

## Project Status Summary (Historical Record)

- ✅ Flutter project created, with all 19 Dart source files (3198 lines)
- ✅ Entire interface localized into Chinese
- ✅ Linux build validation passed
- ✅ Android USB OTG configuration completed
- ✅ Git repository (2 commits)
- ⚠️ Not actually run in an environment with a display (the remote headless environment lacks GPU drivers)

## Architecture

**CLI Wrapper** — The GUI does not implement the PM3 hardware protocol directly; it starts and interacts with the PM3 command line through `dart:io Process`.

```
User action → AppState → PM3Process.sendCommand(stdin)
                          ↓
                     PM3 CLI stdout → OutputParser (regex)
                          ↓
                     Structured data → notifyListeners → UI
```

**Advantage**: PM3 firmware/CLI updates do not affect GUI compatibility.

## Code Navigation

| Feature | Entry File | Description |
|------|----------|------|
| Application startup | `lib/main.dart` | Provider injection |
| Global state | `lib/state/app_state.dart` | Connection/terminal/card/theme |
| PM3 communication | `lib/services/pm3_process.dart` | Process pipes |
| Command templates | `lib/services/pm3_commands.dart` | All PM3 commands |
| Output parsing | `lib/parsers/output_parser.dart` | UID/ATQA/SAK/block/key regex |
| Dump parsing | `lib/parsers/dump_parser.dart` | Automatic .eml/.bin/.json detection |
| Data models | `lib/models/mifare_card.dart` | CardType + MifareCard |
| Access control | `lib/models/access_bits.dart` | Access-bit decoding |
| Home navigation | `lib/ui/home_page.dart` | Bottom navigation with 6 pages |
| Theme | `lib/ui/theme.dart` | Material 3 dark/light |

## Feature Pages

1. **Connection** — PM3 path + serial port selection + connection status
2. **Terminal** — Full-featured terminal + 7 shortcut buttons
3. **Dump Viewer** — Open/view/export MIFARE dump files
4. **High Frequency (Mifare)** — Detection/attacks/read and write/magic cards (4 tabs)
5. **Low Frequency** — General/EM4x05/T55xx (3 tabs)
6. **Settings** — Theme/path/about/maintenance

## To Do

- Signal waveform visualization (fl_chart added but not used)
- Dump file editing
- iClass / Legic / NTAG / DESFire pages
- Command autocomplete + persistent history
- Internationalization framework (currently hard-coded Chinese, no arb files)
- Unit tests
- Actual Windows/Android testing

## Environment Requirements

```bash
# Flutter
export PATH="/opt/flutter/bin:$PATH"
flutter pub get

# Linux build dependencies
pacman -S gtk3  # Arch

# Build
flutter build linux    # Output build/linux/x64/release/bundle/
flutter build apk      # Android

# Run
flutter run -d linux
```

## Notes

- The global gitignore (`~/.gitignore_global`) may exclude `lib/`; `!/lib/` at the end of the project's `.gitignore` overrides this.
- Android USB OTG configuration is in `android/app/src/main/AndroidManifest.xml` and `xml/usb_device_filter.xml`.
- PM3 VID:PID = `9ac4:4b8f`

## References

- [wh201906/Proxmark3GUI](https://github.com/wh201906/Proxmark3GUI) — Qt C++ reference implementation
- [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) — PM3 firmware/CLI
