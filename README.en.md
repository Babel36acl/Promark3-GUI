# PM3 GUI

[简体中文 (Simplified Chinese)](README.md) | **English** | [English quick start](README.quickstart.en.md)

<div align="center">
  <a href="https://github.com/Babel36acl/Promark3-GUI/actions/workflows/build.yml"><img src="https://github.com/Babel36acl/Promark3-GUI/actions/workflows/build.yml/badge.svg" alt="Build"/></a>
  <a href="https://github.com/Babel36acl/Promark3-GUI/releases"><img src="https://img.shields.io/github/v/release/Babel36acl/Promark3-GUI?display_name=tag" alt="Release"/></a>
  <img src="https://img.shields.io/badge/Platforms-Windows%20x64%20%7C%20Linux%20x64-2ea44f" alt="Platforms"/>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0-blue" alt="License"/></a>
</div>

PM3 GUI is a GPL-3.0 open-source desktop graphical client for Proxmark3, providing common RFID/NFC operations, dump file management and a command terminal.

> ⚠️ **Alpha notice**: The current version is still evolving; pages and behavior may change.

Perform operations only on devices, cards and systems that you own or are explicitly authorized to use, and comply with the laws applicable in your location.

## Interface Language

In **Settings → Language**, select **System default**, **简体中文 (Simplified Chinese)** or **English**. Changes take effect immediately, without restarting or disconnecting the device; unsupported system languages use English. The language preference is saved independently and does not affect existing PM3 configuration, drafts or device data. Command help descriptions also switch languages; raw client output, command syntax and export formats remain unchanged.

Only Simplified Chinese and English resources are provided; other Chinese system regions/writing variants use the existing Simplified Chinese resources. Flutter framework text, such as menus and dialogs, follows the application language, while native file pickers continue to use the operating system language.

If saving the language fails, the current session continues using the selected language and Settings displays an error; after fixing the directory or permission problem, select a language again to retry saving. A damaged or unsupported language setting does not prevent the interface from starting.

For translation maintenance, adding languages, current behavior, PR #27 regression coverage and validation limitations, see [Localization](docs.en/localization.md). For the status and historical context of all documents, see the [documentation index](docs.en/README.md); [README.en.html](README.en.html) is the HTML snapshot of this file.

## Platforms and Scope

- Windows x64 is the primary platform for 1.0.
- Linux x64 is an officially supported platform for 1.0.
- Android, iOS, Web and macOS are outside the scope of 1.0.
- This project does not bundle Proxmark3 firmware or the client; device communication uses the official Proxmark3 client installed by the user. On Windows, prefer `pm3.bat` in the official distribution's root directory; on Linux, use `proxmark3`.

The CI workflow includes Windows and Linux x64 desktop paths. Current limited real-device evidence comes from Windows x64: using a user-provided distribution corresponding to RRG commit `da509461` and a PM3EASY512K (identified by the client as `PM3 GENERIC / AT91SAM7S512 / 512K`), client connection, read-only `hw version` and disconnection have been completed through the root-directory `pm3.bat`. Additional validation on 2026-09-05 covered the Mifare page's **Detect Card** action through the real client and device: one click sends one command, and the page displays ATQA/SAK; the client reported MIFARE Classic 1K as a possible type. A command silent for 6 seconds and search output lasting more than 10 seconds have also been verified. These results must not be extrapolated to claim validation of Linux, other devices, card writing, erasing or full firmware interaction.

## Downloads and Releases

- Published versions and Windows/Linux x64 archives are available from [GitHub Releases](https://github.com/Babel36acl/Promark3-GUI/releases). Localization changes belong to [PR #27](https://github.com/Babel36acl/Promark3-GUI/pull/27) and the Unreleased development content below; historical release archives are not guaranteed to include these changes.
- CI for `main` branch commits and Pull Requests generates and checks localization resources and builds releases on both platforms; static analysis and the full tests run in the Linux job. The first run for an external PR may require approval from an upstream maintainer.
- After a tag such as `v0.0.4` is pushed, the same workflow packages both platforms and creates a GitHub Release with automatically generated release notes.
- Releases contain only PM3 GUI; obtain the Proxmark3 client and firmware from [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3).

## Core Capabilities

- Drive the official Proxmark3 client through the `Pm3Backend` contract and `DesktopCliBackend`.
- The terminal supports full command passthrough, history and output viewing.
- Dedicated GUI pages prioritize frequently used workflows; infrequent, diagnostic and new commands remain available in Terminal.
- Feature-page subterminals continue receiving output until the page changes; running another command starts a new capture. Received content remains visible during execution, and the main terminal keeps its output history independently.
- View, analyze and export EML, BIN/DUMP, JSON and key files.
- Connections, command output and process exits have diagnosable local lifecycle management.

```text
Flutter UI / Feature
        │
        ▼
  Pm3Controller → Pm3Backend → DesktopCliBackend
                                      │
                                      ▼
                                  Pm3Process
                                      │
                                      ▼
                         official proxmark3 client
```

`Pm3Process` is the pure Dart process adapter used by `DesktopCliBackend` and reused by the standalone Dart help-synchronization tool; Widgets and Features do not use `dart:io Process` directly. The GUI injects localized messages through the backend; standalone tools do not load Flutter's `dart:ui` and retain Chinese diagnostic defaults.

Pipe mode uses the RRG client's `rem` command to generate sequential completion markers (verified with client `da509461`), so brief pauses or table separators do not cause premature completion. By default, it continues waiting; while a long command is executing, the session can be disconnected from the Connection page. Changing pages only stops subterminal listening and does not terminate the command. Calls with an explicit timeout disconnect the session on timeout to avoid mixing an unfinished command with subsequent output.

Terminal autocomplete selects `docs/pm3_commands_help.zh.yaml` or `docs/pm3_commands_help.yaml` according to the interface language, then merges the `docs/pm3_commands_client.json` client snapshot. Entries added from the snapshot retain the client's original descriptions; no real-time machine translation is performed. After updating the client, run the following read-only help synchronization from the project root; on Windows, use the distribution's root entry point, and for a native client, add the port argument after the path:

```powershell
dart run tools\sync_command_catalog.dart 'C:\path\to\pm3.bat'
```

The Linux example is `dart run tools/sync_command_catalog.dart /usr/bin/proxmark3 /dev/ttyACM0`. First run `flutter pub get` to prepare the package configuration, then run it with the `dart` bundled with Flutter; this is not a `flutter run` entry point. The tool requires an installed client and the corresponding device connection, and does not read the GUI's saved language preference.

Successful synchronization updates `docs/pm3_commands_client.json`; then rebuild the GUI. Calling the tool without arguments displays usage and returns 2; connection/collection failures return 1; success returns 0. The snapshot reflects commands visible to the client and connected device at collection time; it does not mean every feature has a dedicated page or has been validated with a real card.

## Configuration and Privacy

The Connection page selects and persists the serial/device port; Settings manages the client entry-point path, startup arguments and optional working directory. Startup arguments are edited **one argument per line**, preserving spaces, quotes and backslashes exactly as entered. On Windows, prefer `pm3.bat` in the **root directory** of the official distribution; do not bypass the distribution's initialization process by selecting the internal client directly. PM3 GUI starts this script through `cmd.exe /d /c call` and preserves interactive standard input/output; the script initializes the environment, launches the internal client and detects the device automatically, so the GUI's saved port and extra startup arguments are not passed to `.bat`/`.cmd`. Native `proxmark3.exe` and Linux `proxmark3` still start with the selected port.

Devices such as PM3EASY512K that are already supported by the official [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) client use the same entry point; the GUI does not need separate model-specific drivers or an allowlist. These settings use atomic replacement with a temporary file in the same directory, and the interface displays saving or failure status; application shutdown waits for the last settings write. The settings files are located at:

```text
<application support directory>/pm3_settings.json
<application support directory>/language.json
```

These files save client configuration and language preference separately and do not overwrite one another; `language` in `language.json` is `"en"`, `"zh"` or `null` (system default). The application support directory is determined by `path_provider`'s `getApplicationSupportDirectory()` for the current operating system and user account. It is not the project directory; the actual absolute path depends on the system configuration. Language-directory lookup/read/write exceptions appear as settings errors; saving does not silently fall back to the current working directory.

Each successful connection creates a local Session under the same application support directory:

```text
<application support directory>/sessions/YYYY-MM-DD_HHmmss_SSS/
├─ session.json       # Port, client path, start/end times
├─ terminal.log       # Client output
└─ commands.jsonl     # Sent commands (one JSON entry per line)
```

These files are written only to the local machine and are not uploaded by PM3 GUI. Terminal output and command arguments may contain UIDs, device information or other sensitive data; storage error details may also contain personal directory paths. Protect the application support directory, and review and sanitize logs or error reports yourself before sharing them.

## Installation and Running

### Requirements

- Flutter stable (3.47.7 used for this validation)
- Dart SDK bundled with Flutter (3.13.5 used for this validation)
- Official Proxmark3 client: `pm3.bat` in the Windows distribution's root directory, or Linux `proxmark3`

### Run

```bash
git clone https://github.com/Babel36acl/Promark3-GUI.git
cd Promark3-GUI
flutter pub get
flutter run -d windows
```

On Linux x64, use `flutter run -d linux`. First install the corresponding desktop toolchain according to the official Flutter documentation.

If upstream `main` or the selected Release does not yet include PR #27, check out the PR branch in the repository above to try it, then run `flutter pub get`:

```powershell
git fetch https://github.com/Babel36acl/Promark3-GUI.git pull/27/head:pr-27
git switch pr-27
```

### Build

```bash
flutter build windows
flutter build linux
```

## File Formats

The dump viewer's **Command Data** tab can directly edit command-capture results without first generating a dump file. MIFARE `chk/fchk/nested/staticnested/autopwn` results from commands sent by feature pages and the main terminal are collected using the actual sector numbers; `hardnested` requires the command to include `--tblk` and `--ta/--tb` explicitly before its recovered results can be associated. Block tables from `rdbl/rdsc/cgetblk/cgetsc/egetblk/eview/view` are collected using the actual block numbers. Main terminal output remains unchanged.

Before changing cards, use **New Card / Capacity** to clear the draft and select the capacity; detecting a different UID also clears the old data. Missing blocks and keys remain unknown, and trailer blocks read through normal authentication do not treat hidden keys as zero keys. **Keys → Trailer Blocks** and **Trailer Blocks → Keys** explicitly synchronize the two. Draft JSON can save and reopen incomplete data; only complete data can be exported as BIN/EML, only complete sector keys can be exported as key BIN, and known keys can be exported separately as a dictionary. Opening key BIN/key text without a dump opens this tab and does not create a fictitious all-zero dump. When importing drafts or card data, block and key validation uses the currently selected language; a failed import does not change the existing draft, capacity, UID or keys.

File collection scans the configured working directory, the Windows distribution's `client` directory, save/dump paths in the client's `.proxmark3/preferences.json`, and the GUI's default `pm3_files` categorization directory. Scan exceptions appear beside the file-collection heading, while scanning continues in other accessible directories.

| Type | Extension | Read | Export |
|---|---|---:|---:|
| EML dump | `.eml` | ✅ | ✅ |
| Binary dump | `.bin`, `.dump` | ✅ | ✅ |
| JSON dump | `.json` | ✅ | ✅ |
| Key dictionary | `.dic` | ✅ | ✅ |
| Key text | `.keys.txt` | ✅ | ✅ |
| Command-data draft | `.json` (dedicated draft format) | ✅ (Command Data tab) | ✅ |

## Repository Structure

```text
lib/core/pm3/       # Pm3Backend contract, commands, events, results and Session models
lib/backend/         # DesktopCliBackend, Pm3Process and Mock Backend
lib/services/        # Settings, Session, file and command services
lib/state/           # Provider state management
lib/ui/              # Desktop pages and components
lib/l10n/            # ARB resources, language preference state and Flutter localization adaptation
docs/                # Command mappings, specifications and architecture roadmap
.github/workflows/   # Windows/Linux builds and tag-based releases
```

## Development and Validation

Before submitting, you can run:

```powershell
flutter gen-l10n
dart run tools\check_localizations.dart
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
flutter build windows --debug --no-pub
```

Run `dart format` only on the Dart files changed in this contribution; do not reformat unrelated files merely to tidy historical formatting. The commands above cover localization generation/completeness, static analysis, Dart/Flutter tests and a Windows debug build; they do not cover the Linux runner build or replace real PM3 hardware acceptance testing. The CI Linux x64 build path is defined in `.github/workflows/build.yml`.

## Contributing and Security

Issues and Pull Requests are welcome. Before starting, read [CONTRIBUTING.en.md](./CONTRIBUTING.en.md); report security vulnerabilities privately as described in [SECURITY.en.md](./SECURITY.en.md), and do not disclose sensitive details in public Issues.

## Future Roadmap

The next phase will establish a **Command Registry** and **Parser Registry** to unify command metadata, parameters and output parsing. Dedicated GUI pages will continue to prioritize frequently used workflows; infrequent or new commands will remain available through Terminal.

## License

This project uses the **GPL-3.0** license; see [LICENSE](./LICENSE).

The Proxmark3 name, client and firmware belong to their respective upstream projects and contributors; this repository does not distribute or relicense those upstream components.
