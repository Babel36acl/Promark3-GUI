# Changelog

This file records significant changes to PM3 GUI. Version numbers follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Refresh retained command-card save confirmations after language changes,
  preserving status clearing and error replacement. Replace stale translation
  documentation links and describe the implemented HID reader-brute-force labels.

- Refresh retained connection errors when the language changes by storing
  process error kinds and arguments, while keeping the process contract
  Flutter-free and preserving terminal history without retrying the connection.

- Give HID Prox reader brute-force its own tab, heading and action labels,
  without changing genuine key-recovery translations or PM3 command syntax.

- Render retained write-back status and per-block outcomes in the current
  language, including active, finished, cancelled and connection-lost sequences,
  without clearing results or rewriting raw terminal output.

- Report language-directory lookup failures as storage errors so startup
  reaches Settings and queued saves can recover when the directory is available.

- Give the DESFire Applications tab its own resource while preserving the
  editor's Apply action translation.

- Preserve the selected language when validating imported command-card drafts
  and card data, without changing failed-import atomicity.

- Keep command-catalog synchronization runnable with standalone `dart run` by
  adapting Flutter localizations outside the process layer.

- Keep feature-page subterminals displaying output until the page changes, a command is run again, or the page is disposed; output is no longer cut off after 5/8/10 seconds. The main terminal retains its existing display and history behavior.
- Fix commands being sent repeatedly from a single click on a feature page, and loading animations obscuring live output during execution.
- Use sequential client `rem` markers to determine when commands and the Windows handshake have completed, avoiding premature returns caused by silence, table borders and command echoes; reject concurrent sends, and no longer return partially successful results after an explicit timeout.
- Prevent invalid UTF-8 bytes from the Windows client from disconnecting the entire session.

### Added

- Added English and Simplified Chinese ARB localizations, localized framework
  delegates, immediate language switching with a persistent system-default
  option, locale-aware command help and dump analysis, translation checks,
  bilingual UI coverage and an English README. The current catalogs contain
  701 messages per language; native OS dialogs and raw client output are not
  translated by the GUI.

- Synchronize 1033 terminal command entries from the current client's 96 help groups, and provide the `tools/sync_command_catalog.dart` update tool; preserve existing Chinese descriptions.

## [0.0.3] - 2026-09-04

### Added

- Add persistent desktop client settings, connection Session logs and reliable shutdown.
- Add the official Windows `pm3.bat` interactive entry point and support for connecting to physical PM3EASY512K devices.

### Changed

- Consolidate Windows/Linux builds and tag-based releases into one workflow; `v*` tags automatically generate Release artifacts for both platforms.
- Improve the download, contributing, security and GPL-3.0 licensing documentation.

### Fixed

- Fix: Correctly detect found MIFARE keys in `lib/parsers/output_parser.dart` (was incorrectly checking a numeric flag).
- Fix: Improve `sendCommandAndWait` in `lib/backend/desktop_cli/pm3_process.dart` to wait for table terminators (ensures `hf mf autopwn` full output including final key table is captured).

[Unreleased]: https://github.com/Babel36acl/Promark3-GUI/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/Babel36acl/Promark3-GUI/compare/v0.0.3-alpha...v0.0.3
