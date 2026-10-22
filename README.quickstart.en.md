# PM3 GUI

[简体中文 (Simplified Chinese)](README.md) | [English](README.en.md) | **English quick start**

A GPL-3.0 Flutter desktop interface for the official Proxmark3 client.
The interface is available in Simplified Chinese and English.
Windows x64 and Linux x64 are supported desktop targets; the Proxmark3
client and firmware are installed separately.

Only operate on devices, cards and systems you own or are explicitly
authorized to use.

## Languages

Choose **Settings → Language**:

- **System default** follows the operating system's preferred languages.
  Unsupported languages fall back to English.
- **简体中文** selects Simplified Chinese.
- **English** selects English.

Changes apply immediately without restarting or disconnecting the device.
The selection is saved in `language.json` in the operating system's application
support directory, separately from the existing `pm3_settings.json`.
Read/write failures are shown in Settings.
The selected language still applies to the current session if saving fails;
after correcting directory availability or permissions, choose a language again
to retry. Corrupt or unsupported preferences are reported without preventing
the UI from starting. Other Chinese regional/script variants use the shipped
Simplified Chinese bundle; a separate Traditional Chinese bundle is not provided.

The application uses Flutter's standard ARB / `gen-l10n` pipeline, typed
localization accessors, ICU placeholders/plurals and localized Material,
Cupertino and widget delegates. Both languages cover navigation, operation
pages, warnings, editing, dump analysis and application-generated messages.
Terminal command help switches languages as well.
Bundled descriptions follow the selected language, while entries supplied only
by the client snapshot retain their original descriptions. No live translation
service is used.

Proxmark3 commands, protocol names, hexadecimal data, file-format identifiers,
exported machine-readable content and raw client output are intentionally
unchanged. Native operating system file dialogs follow the operating system's
language; their appearance is not controlled by Flutter.

Draft/card imports validate blocks and keys in the selected language. A failed
import leaves the existing draft unchanged. The DESFire **Applications** tab and
the editor's **Apply** action deliberately use separate resources.
See the [localization guide](docs/localization.md) for current behavior,
regression coverage and validation limitations.

## Development

Use the stable Flutter SDK with its bundled Dart SDK and the Windows or Linux
desktop toolchain. This change was developed with Flutter 3.47.7 / Dart 3.13.5;
`flutter pub get` resolves the framework-pinned dependencies for your SDK.

```powershell
git clone https://github.com/Babel36acl/Promark3-GUI.git
Set-Location .\Promark3-GUI
flutter pub get
flutter run -d windows
```

If upstream `main` or a historical release does not yet include PR #27, fetch
the PR branch before `flutter pub get`:

```powershell
git fetch https://github.com/Babel36acl/Promark3-GUI.git pull/27/head:pr-27
git switch pr-27
```

For Linux, run `flutter run -d linux`. If Flutter is not in the current process's
PATH, invoke your installed SDK's `bin\flutter.bat` directly on Windows.

On Windows, select `pm3.bat` in the **root of the official Proxmark3 distribution**
in the connection page or Settings. The script initializes its own environment
and detects devices. Saved GUI port/argument values are not passed to that
script. Native clients, including Linux `proxmark3`, still use the selected
port and arguments. Each launch argument is entered on a separate line;
spaces, quotes and backslashes are preserved.

```powershell
flutter gen-l10n
dart run tools\check_localizations.dart
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
flutter build windows --release --no-pub
```

`flutter pub get` and builds also generate localizations automatically.
Generated localization Dart files are ignored by Git; edit the ARB files,
not generated accessors. Run `dart format` on the Dart files you change rather
than reformatting unrelated historical code.

CI generates and checks translations on Windows and Linux, and builds both
desktop targets. Analysis and the full test suite run in the Linux job.
First-time external contributions may require a maintainer to approve CI.

## Refreshing command help

After `flutter pub get`, use the SDK's standalone Dart VM from the project root:

```powershell
dart run tools\sync_command_catalog.dart 'C:\path\to\pm3.bat'
```

On Linux, use
`dart run tools/sync_command_catalog.dart /usr/bin/proxmark3 /dev/ttyACM0`.
This requires an installed client and its device connection. It updates
`docs/pm3_commands_client.json` on success; rebuild the GUI to include the new
asset. The snapshot reflects the commands available to that client/device,
not a guarantee of GUI coverage or hardware validation.

The tool imports a Flutter-free process layer and does not require a Flutter
engine or read the GUI language preference. Its built-in diagnostic defaults
remain Chinese; raw client output is unchanged. Exit codes are 0 for success,
1 for a connection/collection failure and 2 for invalid arguments.

For translator guidance and adding another language, see
[Localization](docs/localization.md). The original [Chinese README](README.md)
describes file formats, session logging and device integration in more detail.
The [documentation index](docs/README.md) distinguishes current guidance from
historical specifications. [README.html](README.html) is generated from the
Chinese README.

## Privacy and license

The application does not upload device data or session logs. Local logs and
dump files can contain card identifiers, keys and other sensitive information;
storage-error diagnostics can also include local paths. Review and redact
these details before sharing logs or reports.

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and
[LICENSE](LICENSE).
The Proxmark3 client and firmware belong to
[RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3)
and their respective contributors; they are not redistributed by this project.
