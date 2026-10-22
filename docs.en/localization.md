# Localization

## PR #27 scope

PR #27 adds English alongside Simplified Chinese without changing PM3 commands,
protocol identifiers, dump formats or raw client output. There are currently
701 messages in each catalog; `tools/check_localizations.dart` reports the
authoritative count. This is development/Unreleased content, not evidence that
an older release archive contains these features.

Choose **Settings → Language** to follow the system, select **简体中文**
(Simplified Chinese), or select **English**. Unsupported system languages fall
back to English; Chinese regional/script variants use the shipped Simplified
Chinese bundle. Framework menus/dialogs use the app locale, while native file
dialogs keep the OS language. Previously captured terminal output is not
rewritten when the language changes.

## Design

This project follows Flutter's official
[internationalization guide](https://docs.flutter.dev/ui/internationalization):

- `flutter_localizations` supplies framework translations and text direction.
- `lib/l10n/app_en.arb` is the template; `app_zh.arb` preserves Simplified Chinese.
- `l10n.yaml` configures `flutter gen-l10n`; generated Dart files live beside
  the ARB files and are not committed.
- `MaterialApp` uses generated delegates, supported locales and
  `onGenerateTitle`. English is the fallback for unsupported system languages.
- UI code reads `context.l10n`. Stateful pages remain mounted when language
  changes; navigation, text controllers, draft data and connections are retained.
- Domain objects receive localization explicitly through `updateLocalizations`
  or optional `localizations` arguments. There is no mutable global locale or
  run-time dictionary that replaces text in hardware output. The immutable
  Chinese default preserves existing non-UI caller behavior.
- Dump-analysis caches include the locale; terminal suggestions are reloaded
  on locale changes with stale asynchronous results discarded.
- Write-back progress stores a locale-independent status, current block and
  per-block outcomes. The viewer formats these with `context.l10n` on display,
  so active, finished, cancelled and connection-lost sequences follow language
  changes without clearing results or restarting commands. Raw terminal output
  remains unchanged.
- `Pm3Process` depends only on Dart SDK libraries and the pure-Dart
  `Pm3ProcessMessages` contract. Its Chinese defaults preserve standalone-tool
  behavior. `DesktopCliBackend` injects `LocalizedPm3ProcessMessages` to adapt
  generated `AppLocalizations` without pulling Flutter into the process layer.
  Retained connection and lifecycle errors store message kinds and diagnostic
  arguments; `lastError` formats them through the current adapter. Changing
  language refreshes the Connection error card without retrying the connection,
  emitting new output or rewriting historical terminal/session logs.
  Keep these defaults in sync with the Chinese ARB catalog; the message-contract
  tests verify every process message.
- Staging `CommandCard` instances inherit the active localizations before
  validating imported blocks or keys. Failed draft/card imports are atomic.
- Editor save confirmations retain the saved path and format `messageSaved`
  with the current locale when displayed, without saving the file again.
  Successful draft loads clear the status; save/import failures replace it;
  cancelled file dialogs leave the existing status unchanged.
- The DESFire Applications tab uses `desfireApplicationsTab`; the editor's Apply
  verb remains `messageApply`. Shared source-language spelling is not sufficient
  reason to merge resources.
- HID Prox reader brute-force uses the dedicated `hidReaderBruteForceTab`,
  `hidReaderBruteForceTitle` and `hidStartBruteForce` resources. These describe
  facility-code/card-number enumeration against a reader, not cryptographic key
  recovery. Shared key-recovery wording remains available for genuine
  key-recovery workflows.

## Editing messages

Give messages stable, semantic camelCase keys. Localize complete sentences:
do not concatenate translated word fragments, use display text as a storage
key, or decide application behavior by comparing translated strings.
Keep different meanings in separate resources even when one language spells
them identically, such as the DESFire "Applications" noun and editor "Apply" verb.

Each template entry requires `@messageKey` translator metadata. Interpolations
use named ARB placeholders with explicit Dart types. Counts with grammatical
variants use ICU plurals, for example:

```json
{
  "messageCommands": "{value, plural, =0{No commands} =1{1 command} other{{value} commands}}",
  "@messageCommands": {
    "description": "Number of commands in terminal history.",
    "placeholders": {
      "value": {"type": "int"}
    }
  }
}
```

Keep placeholder names identical across languages, but allow translators to
reorder them. Hex values, commands, protocol names, serialized field names and
exported data must remain unchanged. Raw client output and OS diagnostic
details are not machine-translated.

After editing, run these commands from the repository root:

```powershell
flutter gen-l10n
dart run tools\check_localizations.dart
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
```

The resource check rejects missing/extra/empty messages, missing template
metadata and untranslated Chinese in the English catalog. `gen-l10n` validates
ICU syntax and typed placeholders. Tests cover both languages on all 30 pages,
live switching, data retention, persistence, failure reporting, locale fallback,
framework strings, command-help language and locale-aware analysis.
The current page/tab smoke tests use a 1500 × 1100 viewport; the dedicated
DESFire/HID label tests use 1200 × 900. Loaded-dump write-progress tests use
1600 × 1100 to accommodate the fixed-width test font in the existing toolbar.
These are not a substitute for exercising
default/smaller desktop windows, text scaling, dialogs and real hardware.

The focused regression files are:

| Feature | Coverage |
|---|---|
| Preference loading, serialized saves and retries | `test/l10n/app_locale_controller_test.dart` |
| Directory exception conversion and diagnostics | `test/services/locale_settings_store_test.dart` |
| Startup Settings error, switching and page/tab rendering | `test/l10n/localization_test.dart` |
| Standalone message defaults, Flutter adapter and retained connection errors | `test/l10n/pm3_process_messages_test.dart` |
| Connection error card after Settings language changes, without retry/output changes | `test/l10n/localization_test.dart` |
| Retained lifecycle errors with replacement framework-free messages | `test/backend/pm3_process_test.dart` |
| English import errors and atomicity | `test/models/command_card_test.dart` |
| Retained editor save status, cancellation, successful-load clearing and error replacement | `test/ui/command_card_editor_test.dart` |
| Editor save confirmation after Settings language changes, without another save | `test/l10n/localization_test.dart` |
| Applications versus Apply | `test/ui/hf_mfdes_page_test.dart` |
| HID reader brute-force labels, language switching and unchanged command syntax | `test/ui/lf_hid_page_test.dart` |
| Locale-independent write states, mixed block results, cancellation and connection loss | `test/state/write_progress_test.dart` |
| Retained write-back progress/results after Settings language changes | `test/l10n/localization_test.dart` |
| Actual standalone Dart usage/failure paths | `test/tools/sync_command_catalog_test.dart` |

The existing Windows batch-handshake fixture has an intermittent failure that
was also reproduced against unchanged upstream code. Report it separately from
new regressions; do not weaken its assertions or claim a fully clean run when
it fails. Linux builds and real-device operations require their own evidence.

Use wrapping or flexible layouts for captions that expand in translation.
Do not shorten safety warnings to make them fit.

## Adding a language

1. Copy the template to `lib/l10n/app_<language>.arb`, set `@@locale`, and
   translate every message while preserving placeholders.
2. Add the language's native name to the selector in
   `lib/ui/pages/settings_page.dart`. Native language names are deliberately
   constant so users can recover from choosing an unfamiliar language.
3. Run the commands above and exercise the new locale, including dialogs,
   errors, larger text and long captions.
4. If translated command help is available, add its asset and update
   `Pm3CommandCatalog` selection. Otherwise document that command help remains
   in English. Do not translate command syntax.

Generated `supportedLocales` and the preference controller recognize languages
from the ARB files, so a separate hard-coded locale list is not required.

## Preference storage

`LocaleSettingsStore` writes `language.json` in the application support
directory using an exclusive temporary file, a flushed write and same-directory
replacement. `null` means system default. Writes are serialized and flushed
during application exit. Missing files are normal; corrupt, unsupported or
unwritable preferences produce an explicit Settings error.
Path-provider directory-lookup exceptions are converted to storage errors while
preserving their diagnostics and stack traces. Initialization can therefore
continue to the UI, and failed writes do not prevent later saves from retrying.
The current-session selection remains active after a save failure, but is not
guaranteed to survive restart until a later save succeeds. Resolve the
directory/permission problem and choose a language again to retry; there is no
automatic background retry or silent fallback to the working directory.

The stored JSON is `{"language":"en"}`, `{"language":"zh"}` or
`{"language":null}`. Do not translate these codes or the `language` field name.

## Standalone command-catalog synchronization

After `flutter pub get`, `dart run tools\sync_command_catalog.dart` runs on the
standalone Dart VM. With no arguments it prints usage and exits with code 2;
with a client it connects, collects read-only help and writes the snapshot on
success (exit 0). Connection/collection errors return 1.

For Windows, pass the distribution-root `pm3.bat`; for a native client, also
pass its port. This tool does not read `language.json`: it uses the pure-Dart
Chinese diagnostic defaults. It does not load generated Flutter localizations
or translate client output. GUI command help separately selects the bundled
English/Chinese YAML and augments it with the client snapshot.

Language settings are separate from Proxmark3 launch settings and do not change
session records, device data, dump formats or client configuration.
