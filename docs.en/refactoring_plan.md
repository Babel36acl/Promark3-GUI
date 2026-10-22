# PM3 GUI: Current Architecture and Roadmap

This document describes the current implementation baseline and the roadmap.
It is not a commitment to provide a separate page for every Proxmark3 protocol.
Feature priorities are guided by maintainability, common workflows and
compatibility with the official client.

## Platform and version boundaries

- Windows x64 is the primary platform for 1.0.
- Linux x64 is an officially supported platform for 1.0.
- Android, iOS, Web and macOS are outside the supported scope of 1.0.
- PM3 GUI does not bundle firmware or client binaries. Windows uses `pm3.bat`
  from the root of the official distribution; Linux uses the user's installed
  `proxmark3`.
- The existing, limited hardware records come from Windows x64, using the
  distribution corresponding to RRG commit `da509461` and a PM3EASY512K
  (`PM3 GENERIC / AT91SAM7S512 / 512K`). They cover BAT connection, prompt
  recognition, read-only `hw version`, disconnection and the Mifare page's
  read-only detection on 2026-09-05. These are not new hardware validations
  performed for PR #27 and cannot be extrapolated to Linux, other devices,
  card writing/erasure or complete firmware interaction.

## Current architecture

```text
Flutter UI / Feature
        |
        v
  Pm3Controller
        |
        v
    Pm3Backend
        |
        v
DesktopCliBackend
        |
        v
Pm3Process (internal process adapter)
        |
        v
Official Proxmark3 client
```

`Pm3Backend` is the contract between the desktop implementation and the
upper-level state/UI. `DesktopCliBackend` maps the official client process to
connection state, events and command results. The backend and the standalone
Dart help-synchronization tool reuse `Pm3Process`; `dart:io Process` details
do not leak into widgets or features.

### PR #27: UI languages and the tooling boundary

The UI uses Flutter ARB / `gen-l10n` resources and offers Simplified Chinese,
English and system-default selections. Unsupported system languages fall back
to English. `AppLocaleController` manages the current selection, persistence
state and errors; `MaterialApp` uses generated delegates and supported locales.
Changing the language does not recreate connections, page drafts or text
controllers.

`AppLocalizations` stays on the Flutter side. `DesktopCliBackend` adapts it to
the pure-Dart `Pm3ProcessMessages`, so the process layer and
`tools/sync_command_catalog.dart` do not depend on `dart:ui`. Standalone tools
retain their Chinese diagnostic defaults. Commands, hexadecimal data and raw
client output are not translated at runtime.

Language preferences are stored separately in `language.json` in the
application support directory. The `language` value is `en`, `zh` or `null`
(system default). Writes are queued and replace the target using a temporary
file in the same directory; application exit waits for the queue to finish.
Directory-lookup and read/write errors appear in Settings without preventing
initialization. A new selection can retry saving after the directory issue is
fixed; there is no fallback to the working directory.

When importing a draft or card, the temporary `CommandCard` used for validation
inherits the current language, and a failed import does not overwrite existing
data. Dump-analysis caches include the locale. Terminal command help reloads
when the language changes and discards stale asynchronous results. See
[Localization](localization.md) for the maintenance contract for new messages
and languages.

### Client settings

The Connection page selects and persists the serial/device port. Settings
manages these client fields:

- Client executable path.
- Client startup arguments, entered one argument per line in Settings without
  shell tokenization or escaping.
- Optional working directory.

Settings are stored as JSON in `pm3_settings.json` in the application support
directory. Saving first writes a temporary file in the same directory and then
atomically replaces the target. Application shutdown waits for initialization
and the final queued write; the state layer consumes and displays save errors.
The actual root directory comes from `path_provider`'s
`getApplicationSupportDirectory()`, so it varies with the operating system and
user account. Do not hard-code it to the project directory or any fixed
absolute path.

### Local sessions

Each successful connection creates a local session directory:

```text
<application-support-directory>/sessions/YYYY-MM-DD_HHmmss_SSS/
|-- session.json       # Port, client path, start/end times
|-- terminal.log       # Client output, appended line by line
`-- commands.jsonl     # Issued commands, one JSON record per line
```

Writes use a serial queue. On disconnection or application shutdown, the
backend first completes process exit, then closes the session and waits for
trailing writes. This preserves a useful local diagnostic record. Sessions are
not uploaded. Terminal output may contain sensitive information such as UIDs,
device details or command arguments; users should protect the application
support directory according to their local security requirements.

### Process lifecycle

Connection handles early client exit and startup failure. Disconnection first
requests a graceful client exit, waits for a bounded interval and only then
forces termination. It also cleans up stdout/stderr subscriptions and process
references. On Windows, forced termination targets only the exact PID already
held by the application and terminates that PID's process tree. On POSIX, TERM
is sent first, escalating to KILL after a bounded wait. Application shutdown
waits for settings writes, the session queue, application subscriptions and
backend resources to be released.

## Feature coverage strategy

Dedicated GUI pages cover only frequently used, stable workflows that benefit
from structured interaction. Infrequently used protocols, diagnostic commands
and new official-client commands remain available through the Terminal page.
This preserves full command access without maintaining duplicate pages and
incomplete parameter wrappers for every protocol.

Current navigation groups general functions, high-frequency (HF),
low-frequency (LF) and tools. Existing pages and command mappings are defined
by `lib/ui/pages/`, `lib/services/pm3_commands.dart`,
`docs/pm3_commands*.yaml` and `docs/pm3_commands_client.json` in the repository.
The number of protocol pages is not the coverage metric for 1.0.

## Next phase

The next phase begins with two reusable registries:

1. **Command Registry:** unify command metadata, parameter definitions,
   capability flags and UI availability.
2. **Parser Registry:** unify output parsers, structured results and
   version-compatibility strategies.

Once the registries are stable, add a small number of dedicated GUI pages
based on actual usage frequency. Infrequent or not-yet-modeled commands
continue to use Terminal. Each extension should preserve passthrough access to
the official client and add the corresponding tests and documentation.

## Validation boundaries

Dart formatting checks, Flutter static analysis, the complete Flutter test
suite and a Windows debug build on a Windows x64 workstation provide
code-level validation of the desktop foundation. The repository's CI workflow
also declares a Linux x64 build path, but local results do not replace an
actual build on a Linux runner.

PR #27's CI generates and checks localization resources on Windows and Linux.
Static analysis and the complete test suite run in the Linux job. See
[Localization](localization.md) for the specific language, storage-recovery,
import and UI regression tests and their limitations. References to earlier
hardware records do not mean that all hardware acceptance checks were
repeated for these localization changes.

The existing hardware records cover only the Windows distribution
corresponding to RRG commit `da509461` and one PM3EASY512K
(`PM3 GENERIC / AT91SAM7S512 / 512K`): the root-level `pm3.bat` can connect,
produce a real prompt, execute read-only `hw version` and disconnect. The
2026-09-05 record also includes the Mifare page's Detect card operation
displaying ATQA/SAK. There is still no acceptance evidence here for Linux,
other devices, card writing/erasure or complete firmware interaction.
