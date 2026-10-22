import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/core/pm3/pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/core/pm3/pm3_command.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/core/pm3/pm3_event.dart';
import 'package:pm3gui/core/pm3/pm3_result.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/state/connection_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  test('write statuses and block outcomes format in the requested locale', () {
    final progress = WriteProgress(total: 3);
    expect(progress.localizedStatus(en), isEmpty);
    expect(progress.localizedStatus(zh), isEmpty);
    expect(progress.progress, 0);
    expect(progress.isRunning, isTrue);
    expect(progress.cancelled, isFalse);

    progress
      ..status = WriteStatus.writing
      ..currentBlock = 17;
    expect(progress.localizedStatus(en), en.messageWritingBlock('17'));
    expect(progress.localizedStatus(zh), zh.messageWritingBlock('17'));
    expect(progress.isRunning, isTrue);

    progress
      ..completed = 3
      ..succeeded = 2
      ..failed = 1
      ..status = WriteStatus.finished;
    expect(progress.localizedStatus(en),
        en.messageFinishedSucceededFailed('2', '1'));
    expect(progress.localizedStatus(zh),
        zh.messageFinishedSucceededFailed('2', '1'));
    expect(progress.progress, 1);
    expect(progress.isRunning, isFalse);
    expect(progress.cancelled, isFalse);

    for (final status in [WriteStatus.cancelled, WriteStatus.connectionLost]) {
      progress
        ..completed = 1
        ..status = status;
      expect(progress.cancelled, isTrue);
      expect(progress.isRunning, isFalse);
      for (final l10n in [en, zh]) {
        expect(
            progress.localizedStatus(l10n),
            status == WriteStatus.cancelled
                ? l10n.messageCancelled
                : l10n.messageConnectionLostOperationAborted);
      }
    }

    const success = WriteBlockResult(block: 4, success: true);
    const failure = WriteBlockResult(block: 5, success: false);
    for (final l10n in [zh, en, zh]) {
      expect(success.localizedMessage(l10n), l10n.messageWriteSuccessful);
      expect(failure.localizedMessage(l10n),
          l10n.messageAuthenticationOrWritingFailed);
    }
  });

  test('completed sequences retain mixed results across locale changes',
      () async {
    final backend = _WriteBackend();
    final app = _appState(backend)..updateLocalizations(zh);
    addTearDown(app.shutdown);
    final progress = await app.sendCommandSequence(
      [(4, 'write-ok'), (5, 'write-auth-fail'), (6, 'write-fail')],
      delayBetween: Duration.zero,
    );
    final results = progress.results.toList();
    final rawOutput = app.terminalOutput.toList();

    expect(progress.status, WriteStatus.finished);
    expect(progress.completed, 3);
    expect(progress.succeeded, 1);
    expect(progress.failed, 2);
    expect(progress.results.map((r) => (r.block, r.success)),
        [(4, true), (5, false), (6, false)]);
    expect(backend.commands, ['write-ok', 'write-auth-fail', 'write-fail']);
    expect(progress.localizedStatus(zh),
        zh.messageFinishedSucceededFailed('1', '2'));

    for (final l10n in [en, zh]) {
      app.updateLocalizations(l10n);
      expect(app.writeProgress, same(progress));
      expect(progress.results, orderedEquals(results));
      expect(progress.localizedStatus(l10n),
          l10n.messageFinishedSucceededFailed('1', '2'));
      expect(progress.results.first.localizedMessage(l10n),
          l10n.messageWriteSuccessful);
      expect(progress.results.last.localizedMessage(l10n),
          l10n.messageAuthenticationOrWritingFailed);
      expect(app.terminalOutput, rawOutput);
    }
    app.cancelWriteSequence();
    expect(progress.status, WriteStatus.finished);
  });

  test('locale switching and cancellation retain the in-flight block result',
      () async {
    final gate = Completer<void>();
    final backend = _WriteBackend(commandGate: gate);
    final app = _appState(backend)..updateLocalizations(zh);
    addTearDown(app.shutdown);
    final writing = app.sendCommandSequence(
      [(17, 'write-ok'), (18, 'write-ok')],
      delayBetween: Duration.zero,
    );
    final progress = app.writeProgress!;
    expect(progress.status, WriteStatus.writing);
    expect(progress.currentBlock, 17);
    expect(progress.localizedStatus(zh), zh.messageWritingBlock('17'));

    app.updateLocalizations(en);
    expect(app.writeProgress, same(progress));
    expect(progress.localizedStatus(en), en.messageWritingBlock('17'));
    expect(progress.isRunning, isTrue);
    app.cancelWriteSequence();
    expect(progress.localizedStatus(en), en.messageCancelled);
    expect(progress.isRunning, isFalse);
    gate.complete();
    expect(await writing, same(progress));

    expect(progress.status, WriteStatus.cancelled);
    expect(progress.completed, 1);
    expect(progress.succeeded, 1);
    expect(progress.failed, 0);
    expect(progress.results.single.block, 17);
    expect(backend.commands, ['write-ok']);
    app.updateLocalizations(zh);
    expect(progress.localizedStatus(zh), zh.messageCancelled);
    expect(progress.results.single.localizedMessage(zh),
        zh.messageWriteSuccessful);
    app.updateLocalizations(en);
    expect(progress.localizedStatus(en), en.messageCancelled);
    expect(progress.results.single.localizedMessage(en),
        en.messageWriteSuccessful);
  });

  test('connection loss retains previous block results in both languages',
      () async {
    final backend = _WriteBackend();
    final app = _appState(backend)..updateLocalizations(zh);
    addTearDown(app.shutdown);
    app.addListener(() {
      if (app.writeProgress?.completed == 1 && backend.connected) {
        unawaited(backend.disconnect());
      }
    });
    final progress = await app.sendCommandSequence(
      [(4, 'write-ok'), (5, 'write-ok')],
      delayBetween: Duration.zero,
    );

    expect(progress.status, WriteStatus.connectionLost);
    expect(progress.cancelled, isTrue);
    expect(progress.completed, 1);
    expect(progress.succeeded, 1);
    expect(progress.failed, 0);
    expect(backend.commands, ['write-ok']);
    final result = progress.results.single;
    for (final l10n in [en, zh]) {
      app.updateLocalizations(l10n);
      expect(progress.localizedStatus(l10n),
          l10n.messageConnectionLostOperationAborted);
      expect(progress.results.single, same(result));
      expect(result.block, 4);
      expect(result.localizedMessage(l10n), l10n.messageWriteSuccessful);
    }
    app.cancelWriteSequence();
    expect(progress.status, WriteStatus.connectionLost);
  });

  test('empty sequences finish without any block results or commands',
      () async {
    final backend = _WriteBackend();
    final app = _appState(backend);
    addTearDown(app.shutdown);
    final progress = await app.sendCommandSequence([]);
    expect(progress.status, WriteStatus.finished);
    expect(progress.isRunning, isFalse);
    expect(progress.progress, 0);
    expect(progress.results, isEmpty);
    expect(backend.commands, isEmpty);
  });
}

AppState _appState(_WriteBackend backend) => AppState(
      connectionState: ConnectionState(
        controller: Pm3Controller(backend),
        settingsStore: _Settings(),
      ),
    );

class _Settings implements Pm3SettingsRepository {
  @override
  Future<Pm3ClientSettings?> load() async => null;
  @override
  Future<void> save(Pm3ClientSettings settings) async {}
}

class _WriteBackend implements Pm3Backend {
  _WriteBackend({this.commandGate});

  final Completer<void>? commandGate;
  final _events = StreamController<Pm3Event>.broadcast(sync: true);
  final commands = <String>[];
  bool connected = true;

  @override
  Stream<Pm3Event> get events => _events.stream;
  @override
  Pm3ConnectionState get state => connected
      ? Pm3ConnectionState.connected
      : Pm3ConnectionState.disconnected;
  @override
  String get version => 'test';
  @override
  String get lastError => '';
  @override
  Future<void> connect(Pm3ConnectionConfig config) async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> shutdown() => _events.close();

  @override
  Future<Pm3Result> execute(Pm3Command command, {Duration? timeout}) async {
    commands.add(command.executable);
    final startedAt = DateTime.now();
    final output = switch (command.executable) {
      'write-auth-fail' => 'Auth error',
      'write-fail' => '( fail )',
      _ => '[+] writing\n[+] written\n[+] done',
    };
    for (final line in output.split('\n')) {
      _events.add(Pm3OutputEvent(DateTime.now(), line));
    }
    await commandGate?.future;
    return Pm3Result(
      command: command,
      output: output,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
    );
  }
}
