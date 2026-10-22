import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/desktop_cli/desktop_cli_backend.dart';
import 'package:pm3gui/backend/desktop_cli/pm3_process.dart';
import 'package:pm3gui/backend/desktop_cli/pm3_process_messages.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/l10n/app_localizations.dart';
import 'package:pm3gui/l10n/localized_pm3_process_messages.dart';

void main() {
  test('standalone Chinese defaults match every generated process message', () {
    final chinese = lookupAppLocalizations(const Locale('zh'));
    expect(
      _snapshot(const Pm3ProcessMessages()),
      _snapshot(LocalizedPm3ProcessMessages(chinese)),
    );
  });

  test('backend adapts live language changes without changing the process',
      () async {
    final process = Pm3Process();
    final backend = DesktopCliBackend(process: process);
    addTearDown(backend.shutdown);
    final english = lookupAppLocalizations(const Locale('en'));
    final chinese = lookupAppLocalizations(const Locale('zh'));

    backend.updateLocalizations(english);
    expect(process.l10n, isA<LocalizedPm3ProcessMessages>());
    expect(process.l10n.pm3Busy, english.pm3Busy);
    expect(process.l10n.messageConnectionFailed('detail'),
        english.messageConnectionFailed('detail'));
    expect(process.l10n.messageCouldNotStartPm3PathCheckThe('error', 'path'),
        english.messageCouldNotStartPm3PathCheckThe('error', 'path'));
    expect(process.l10n.messagePm3ProgramNotFoundOnWindowsSelect('path'),
        english.messagePm3ProgramNotFoundOnWindowsSelect('path'));

    backend.updateLocalizations(chinese);
    expect(_snapshot(process.l10n), _snapshot(const Pm3ProcessMessages()));
  });

  test('process accepts a framework-independent message implementation',
      () async {
    final process = Pm3Process(l10n: const _CustomMessages());
    await process.shutdown();

    expect(await process.connect('unused-client', 'unused-port'), isFalse);
    expect(process.lastError, 'custom disposed message');
    process.l10n = const _CustomMessages('replacement disposed message');
    expect(process.lastError, 'replacement disposed message');
  });

  test('missing-client error follows the locale without reconnecting or output',
      () async {
    var starts = 0;
    final process = Pm3Process(
      processStarter: (_, __, {workingDirectory}) async {
        starts++;
        throw StateError('A missing client must not be started');
      },
    );
    final backend = DesktopCliBackend(process: process);
    addTearDown(backend.shutdown);
    final output = <String>[];
    final states = <Pm3ProcessState>[];
    final outputSubscription = process.outputStream.listen(output.add);
    final stateSubscription = process.stateStream.listen(states.add);
    addTearDown(outputSubscription.cancel);
    addTearDown(stateSubscription.cancel);
    final chinese = lookupAppLocalizations(const Locale('zh'));
    final english = lookupAppLocalizations(const Locale('en'));
    final path = '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'pm3gui-missing-${DateTime.now().microsecondsSinceEpoch}.exe';
    expect(File(path).existsSync(), isFalse);
    backend.updateLocalizations(chinese);

    await backend.connect(Pm3ConnectionConfig(executable: path, port: 'test'));

    final originalOutput = [
      chinese
          .messageError(chinese.messagePm3ProgramNotFoundOnWindowsSelect(path)),
    ];
    expect(output, originalOutput);
    expect(states, [Pm3ProcessState.connecting, Pm3ProcessState.disconnected]);
    for (final l10n in [chinese, english, chinese]) {
      backend.updateLocalizations(l10n);
      final expected = l10n.messagePm3ProgramNotFoundOnWindowsSelect(path);
      expect(process.lastError, expected);
      expect(backend.lastError, expected);
      expect(backend.state, Pm3ConnectionState.disconnected);
      expect(output, originalOutput);
      expect(
          states, [Pm3ProcessState.connecting, Pm3ProcessState.disconnected]);
      expect(starts, 0);
    }
  });

  for (final failure in [
    ProcessException('client', const [], 'raw OS diagnostic 37'),
    StateError('raw startup diagnostic 42'),
  ]) {
    test('retained ${failure.runtimeType} arguments follow the locale',
        () async {
      var starts = 0;
      final process = Pm3Process(
        processStarter: (_, __, {workingDirectory}) async {
          starts++;
          throw failure;
        },
      );
      final backend = DesktopCliBackend(process: process);
      addTearDown(backend.shutdown);
      final output = <String>[];
      final subscription = process.outputStream.listen(output.add);
      addTearDown(subscription.cancel);
      final chinese = lookupAppLocalizations(const Locale('zh'));
      final english = lookupAppLocalizations(const Locale('en'));
      final path = Platform.resolvedExecutable;
      backend.updateLocalizations(chinese);

      await backend
          .connect(Pm3ConnectionConfig(executable: path, port: 'test'));

      final originalOutput = output.toList();
      for (final l10n in [chinese, english, chinese]) {
        backend.updateLocalizations(l10n);
        final expected = failure is ProcessException
            ? l10n.messageCouldNotStartPm3PathCheckThe(failure.message, path)
            : l10n.messageConnectionFailed(failure.toString());
        expect(backend.lastError, expected);
        expect(output, originalOutput);
        expect(starts, 1);
        expect(backend.state, Pm3ConnectionState.disconnected);
      }
    });
  }
}

List<String> _snapshot(Pm3ProcessMessages messages) => [
      messages.messageConnectionFailed('detail'),
      messages.messageConnectionTimedOut,
      messages.messageConnectionTimedOutSCheckThatThe('3'),
      messages.messageCoolingDownS('3'),
      messages.messageCouldNotReadTheExitStatusAfter('stdout', 'detail'),
      messages.messageCouldNotStartPm3PathCheckThe('detail', 'path'),
      messages.messageError('detail'),
      messages.messageErrorCommandTimedOutTheSessionWas,
      messages.messageFailedToForceTerminatePm3KillProcess,
      messages.messageFailedToSendQuit('detail'),
      messages.messageFailedToSendTheReadOnlyPm3('detail'),
      messages.messageFailedToTerminatePm3('detail'),
      messages.messageFailedToTerminatePm3ReturnedFalse('TERM'),
      messages.messageFailedToTerminatePm3TermProcessTree,
      messages.messageFailedWhileWaitingForPm3ToExit('detail'),
      messages.messageFailedWhileWaitingForPm3ToStart('detail'),
      messages.messageFatalErrorOnPm3Stderr,
      messages.messageFatalErrorOnPm3Stdout,
      messages.messageNotConnected,
      messages.messagePermissionDeniedForTheSerialPortTry,
      messages.messagePleaseWaitSecondsBeforeRetrying('3'),
      messages.messagePm3ProcessExitStatusError('detail'),
      messages.messagePm3ProcessExitedBeforeTheConnectionPrompt('9'),
      messages.messagePm3ProcessExitedCode('9'),
      messages.messagePm3ProgramNotFoundOnWindowsSelect('path'),
      messages.messagePm3StderrStreamError('detail'),
      messages.messagePm3StdoutStreamError('detail'),
      messages.messagePm3StreamClosed('stdout'),
      messages.messageSerialConnectionError('detail'),
      messages.messageSerialDeviceNotFoundCheckThePm3,
      messages.messageThePm3ProcessManagerHasBeenDisposed,
      messages.messageThePm3SessionDisconnectedBeforeTheCommand,
      messages.messageTheSerialPortIsInUseBy,
      messages.messageTimedOutWaitingForPm3ToExit,
      messages.messageUsingPm3('path'),
      messages.messageWorkingDirectory('directory'),
      messages.pm3Busy,
    ];

class _CustomMessages extends Pm3ProcessMessages {
  const _CustomMessages([this.disposedMessage = 'custom disposed message']);

  final String disposedMessage;

  @override
  String get messageThePm3ProcessManagerHasBeenDisposed => disposedMessage;
}
