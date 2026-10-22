# PM3 Desktop Foundation Implementation Plan

> **Historical implementation plan (2026-09-04).** The steps and execution
> notes below record the development process at that time. They are not new
> instructions for the current agent to execute. See
> [Localization](../../localization.md) for PR #27's language-state,
> standalone-Dart tooling boundary and storage-recovery contracts. Follow
> [CONTRIBUTING](../../../CONTRIBUTING.en.md) for the current development
> workflow.

> **For agent workers:** Required sub-skill: use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax to track progress.

**Goal:** Add Windows/Linux client-configuration persistence, local session
logs and reliable process exit on top of the completed `Pm3Backend` boundary,
giving Phase 2 a runnable and testable desktop foundation.

**Architecture:** Configuration and sessions are local desktop capabilities.
Small services inject them into `ConnectionState`/`AppState` without exposing
process details to features or widgets. `Pm3Process` remains an internal adapter
for `DesktopCliBackend`, but explicitly owns stdout/stderr subscriptions, the
exit handshake and the dispose lifecycle. All new file writes are restricted
to the application support directory. They neither access the network nor
record key-vault credentials.

**Technology stack:** Flutter Desktop, Dart `dart:io`/`dart:convert`, Provider,
`path_provider`, `file_selector`, `flutter_test`.

---

## File structure

- Create `lib/core/pm3/pm3_client_settings.dart`: serializable desktop client
  settings.
- Create `lib/services/pm3_settings_store.dart`: load, validate and save the
  JSON settings file.
- Modify `lib/state/connection_state.dart`: load/save the client path, working
  directory, arguments and serial port.
- Modify `lib/state/app_state.dart`: expose initialization state and settings
  operations.
- Modify `lib/ui/pages/settings_page.dart` and
  `lib/ui/pages/connection_page.dart`: provide real file selection and feedback
  on settings state.
- Create `lib/core/pm3/pm3_session.dart`: session metadata and command-record
  models.
- Create `lib/services/pm3_session_recorder.dart`: write `session.json`,
  `terminal.log` and `commands.jsonl`.
- Modify `lib/core/pm3/pm3_controller.dart` and `lib/state/app_state.dart`: connect
  commands and backend events to the session.
- Modify `lib/backend/desktop_cli/pm3_process.dart`: reliably handle early exit,
  graceful exit, forced termination and disposal.
- Modify `lib/backend/desktop_cli/desktop_cli_backend.dart`: await underlying
  shutdown and ensure the order in which subscriptions are released.
- Create `test/services/pm3_settings_store_test.dart`,
  `test/services/pm3_session_recorder_test.dart` and
  `test/backend/pm3_process_test.dart`.
- Modify `README.md` and `docs/refactoring_plan.md`: synchronize the
  Windows/Linux-only scope and Phase 2 status.

### Task 1: Client-settings persistence and path selection

**Files:**
- Create: `lib/core/pm3/pm3_client_settings.dart`
- Create: `lib/services/pm3_settings_store.dart`
- Modify: `lib/state/connection_state.dart`
- Modify: `lib/state/app_state.dart`
- Modify: `lib/ui/pages/settings_page.dart`
- Modify: `lib/ui/pages/connection_page.dart`
- Test: `test/services/pm3_settings_store_test.dart`
- Test: `test/state/connection_state_test.dart`

- [x] **Step 1: Write failing settings-store tests**

```dart
test('round-trips desktop client settings', () async {
  final directory = await Directory.systemTemp.createTemp('pm3-settings-');
  addTearDown(() => directory.delete(recursive: true));
  final store = Pm3SettingsStore(directoryProvider: () async => directory);
  const expected = Pm3ClientSettings(
    executable: r'C:\tools\proxmark3.exe',
    port: 'COM7',
    arguments: ['--flush'],
    workingDirectory: r'C:\tools',
  );
  await store.save(expected);
  expect(await store.load(), expected);
});

test('invalid JSON falls back without throwing', () async {
  // After invalid JSON is written, load() returns null instead of failing startup.
});
```

- [x] **Step 2: Run the red tests**

Run: `flutter test --no-pub test/services/pm3_settings_store_test.dart`

Expected: FAIL because `Pm3ClientSettings` and `Pm3SettingsStore` do not exist.

- [x] **Step 3: Implement the minimal model and storage**

```dart
final class Pm3ClientSettings {
  const Pm3ClientSettings({
    required this.executable,
    this.port = '',
    this.arguments = const [],
    this.workingDirectory,
  });

  final String executable;
  final String port;
  final List<String> arguments;
  final String? workingDirectory;

  Map<String, Object?> toJson() => <String, Object?>{
        'executable': executable,
        'port': port,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
      };
}
```

`Pm3SettingsStore` uses an injected directory provider and saves JSON to
`pm3_settings.json`. `load()` returns `null` for a missing file, invalid JSON or
invalid fields.

- [x] **Step 4: Wire settings into the state layer and UI**

`ConnectionState.initialize()` restores settings at startup. `setPm3Path`,
`setPort` and the new argument/working-directory setters save snapshots.
Settings and Connection use `FileDialogService.pickSingleFilePath()` to select
`proxmark3.exe`/`proxmark3`; users are no longer limited to typing paths manually.

- [x] **Step 5: Run the green tests and related regressions**

Run:

```text
flutter test --no-pub test/services/pm3_settings_store_test.dart test/state/connection_state_test.dart
flutter test --no-pub
```

Expected: all tests pass.

- [x] **Step 6: Commit**

```text
feat(settings): persist PM3 client settings
```

### Task 2: Local sessions and unified logging

**Files:**
- Create: `lib/core/pm3/pm3_session.dart`
- Create: `lib/services/pm3_session_recorder.dart`
- Modify: `lib/core/pm3/pm3_controller.dart`
- Modify: `lib/state/app_state.dart`
- Test: `test/services/pm3_session_recorder_test.dart`
- Test: `test/backend/pm3_controller_test.dart`

- [x] **Step 1: Write failing session tests**

```dart
test('records metadata, terminal output and command history', () async {
  final directory = await Directory.systemTemp.createTemp('pm3-session-');
  addTearDown(() => directory.delete(recursive: true));
  final recorder = Pm3SessionRecorder(rootDirectoryProvider: () async => directory);
  await recorder.start(devicePort: 'COM7', executable: 'proxmark3.exe');
  await recorder.recordCommand('hw version');
  await recorder.recordOutput('[+] client: v4');
  await recorder.close();
  expect(await File('${recorder.sessionPath}/session.json').exists(), isTrue);
  expect(await File('${recorder.sessionPath}/terminal.log').readAsString(), contains('client: v4'));
  expect(await File('${recorder.sessionPath}/commands.jsonl').readAsString(), contains('hw version'));
});
```

- [x] **Step 2: Run the red tests**

Run: `flutter test --no-pub test/services/pm3_session_recorder_test.dart`

Expected: FAIL because the session types and recorder do not exist.

- [x] **Step 3: Implement a session recorder with serialized writes**

Each successful connection creates `sessions/YYYY-MM-DD_HHmmss_SSS/` and
immediately writes `session.json`. All output is appended to `terminal.log`.
All commands are appended to `commands.jsonl` as single-line JSON records.
An internal Future chain serializes writes. `close()` waits for trailing
writes and stores `endedAt` in the metadata.

- [x] **Step 4: Wire the controller and application state**

`Pm3Controller.execute()` emits a command observation before calling the
backend. `AppState` starts a session on connected, records output events and
closes the session on disconnected/dispose. Recording failures update only
local diagnostic state; they do not block PM3 commands.

- [x] **Step 5: Run the green tests and related regressions**

Run:

```text
flutter test --no-pub test/services/pm3_session_recorder_test.dart test/backend/pm3_controller_test.dart
flutter test --no-pub
```

Expected: all tests pass and demonstrate that file contents are complete after
close.

- [x] **Step 6: Commit**

```text
feat(logging): add local PM3 session records
```

### Task 3: Reliable PM3 process lifecycle

**Files:**
- Modify: `lib/backend/desktop_cli/pm3_process.dart`
- Modify: `lib/backend/desktop_cli/desktop_cli_backend.dart`
- Test: `test/backend/pm3_process_test.dart`

- [x] **Step 1: Write failing process-lifecycle tests**

Tests create a Dart child-process fixture at runtime. One prints `pm3 -->` on
startup and exits when it receives `quit`; another exits before printing the
prompt. The historical assertion below checks the legacy Chinese diagnostic
word `退出` ("exit"), which is preserved verbatim rather than changing the
behavior of the example.

```dart
test('disconnect waits for a graceful child exit', () async {
  final process = Pm3Process(connectCooldown: Duration.zero);
  expect(await process.connect(dartExecutable, 'COM7', arguments: fixtureArgs), isTrue);
  await process.disconnect();
  expect(process.state, Pm3ProcessState.disconnected);
});

test('connect returns false when child exits before prompt', () async {
  final process = Pm3Process(connectCooldown: Duration.zero);
  expect(await process.connect(dartExecutable, 'COM7', arguments: earlyExitArgs), isFalse);
  expect(process.lastError, contains('退出'));
});
```

- [x] **Step 2: Run the red tests**

Run: `flutter test --no-pub test/backend/pm3_process_test.dart`

Expected: FAIL. The existing constructor does not allow cooldown injection,
and an early-exit connection waits for the 15-second timeout.

- [x] **Step 3: Implement the minimal lifecycle fix**

Retain stdout/stderr subscriptions and complete the connection Future on early
exit. `disconnect()` first writes `quit`, waits for a bounded interval and
calls `kill()` only on timeout. Publish disconnected after clearing
subscriptions and process references. `dispose()` marks the instance as
released and ensures later asynchronous callbacks do not write to closed
controllers.

- [x] **Step 4: Run the green tests and related regressions**

Run:

```text
flutter test --no-pub test/backend/pm3_process_test.dart
flutter test --no-pub
```

Expected: all tests pass and no test processes remain.

- [x] **Step 5: Commit**

```text
fix(backend): improve the PM3 process-exit lifecycle
```

### Task 4: Documentation, static checks and desktop-build validation

**Files:**
- Modify: `README.md`
- Modify: `docs/refactoring_plan.md`

- [x] **Step 1: Synchronize the design baseline**

State that Windows x64 is the primary platform and Linux x64 is officially
supported; Android/macOS/Web are outside 1.0. Record external-client settings,
local session files, the backend lifecycle and the next Command/Parser work.

- [x] **Step 2: Formatting and static checks**

Run:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
```

Expected: changed files are formatted correctly, and analysis introduces no
warnings/errors. Report the repository's four existing `avoid_print` infos in
`tools/verify_extract.dart` separately.

- [x] **Step 3: Complete test suite and Windows build**

Run:

```text
flutter test --no-pub
flutter build windows --debug --no-pub
```

Expected: zero failing tests and Windows debug build exit code 0. A Linux
build requires a Linux host; the current Windows environment can perform only
static review of the code paths and CI configuration.

- [x] **Step 4: Commit**

```text
docs(architecture): update desktop-foundation implementation status
```

### Task 5: RRG Windows BAT client compatibility and hardware recheck

**Files:**
- Modify: `lib/backend/desktop_cli/pm3_process.dart`
- Modify: `lib/backend/desktop_cli/desktop_cli_backend.dart`
- Modify: `lib/state/connection_state.dart`
- Modify: `lib/ui/pages/connection_page.dart`
- Modify: `lib/ui/pages/settings_page.dart`
- Add: `test/backend/desktop_cli_backend_test.dart`
- Modify: `test/backend/pm3_process_test.dart`
- Modify: `test/state/connection_state_test.dart`
- Modify: `README.md`
- Modify: `docs/refactoring_plan.md`

- [x] **Step 1: Write failing tests for the BAT entry point**

When `pm3.bat` is selected on Windows, the process layer must launch it through
`cmd.exe /d /c call` and keep stdin/stdout interactive. Intermediate
"establishing USB communication" output must not be mistaken for a connected
prompt.

- [x] **Step 2: Run the red tests**

Run: `flutter test --no-pub test/backend/pm3_process_test.dart`

Expected: FAIL. The existing implementation passes `.bat` directly to
`Process.start` and accepts `Communicating with PM3 over USB-CDC` too early.

The actual red tests also cover the RRG BAT launcher not flushing its
waiting-for-input prompt through a stdout pipe: connection times out without
active input. A standalone `[usb]` transport tag must not count as evidence
of success either.

- [x] **Step 3: Implement the minimal BAT adaptation**

Only Windows `.bat`/`.cmd` entry points launch through the system command
interpreter. Native `proxmark3.exe` and Linux `proxmark3` paths retain their
existing behavior. After a Windows BAT client first reports USB-CDC
communication, send one read-only `hw version` handshake to advance pipe
output. Recognize real `pm3 -->` prompts across chunks and without a final
newline. Intermediate communication lines or standalone transport tags do not
mean a successful connection. Settings and default-path guidance should prefer
the distribution-root `pm3.bat` for Windows users.

- [x] **Step 4: Hardware and regression validation**

On Windows x64, the user-provided distribution corresponding to RRG commit
`da509461` and a PM3EASY512K (`PM3 GENERIC / AT91SAM7S512 / 512K`) were used to
verify the root `pm3.bat` connection chain, real prompt recognition, read-only
`hw version` and disconnection. This evidence does not cover Linux, other
devices, complete firmware interaction or actual card operations. The full
Flutter test suite, changed-scope static checks and a Windows debug build
passed.

- [x] **Step 5: Commit**

The recorded commit descriptions below are translated into English; their
commit hashes are unchanged.

```text
2cc4242 feat(backend): support the official Windows PM3 script
36452ec fix(backend): recognize PM3 prompts without a newline
471dfa6 fix(backend): wake the Windows BAT interactive prompt
```
