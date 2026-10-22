import 'dart:async';
import 'dart:io';

import 'package:pm3gui/core/pm3/pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_command.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/core/pm3/pm3_event.dart';
import 'package:pm3gui/core/pm3/pm3_result.dart';

import 'pm3_process.dart';
import 'package:pm3gui/l10n/localized_messages.dart';
import 'package:pm3gui/l10n/localized_pm3_process_messages.dart';

/// Desktop backend backed by the official Proxmark3 CLI process.
final class DesktopCliBackend with LocalizedMessages implements Pm3Backend {
  DesktopCliBackend({Pm3Process? process})
      : _process = process ?? Pm3Process() {
    _outputSubscription = _process.outputStream.listen((line) {
      _events.add(Pm3OutputEvent(DateTime.now(), line));
    });
    _stateSubscription = _process.stateStream.listen((state) {
      _events.add(Pm3StateChangedEvent(DateTime.now(), _mapState(state)));
    });
  }

  final Pm3Process _process;
  final StreamController<Pm3Event> _events =
      StreamController<Pm3Event>.broadcast(sync: true);
  late final StreamSubscription<String> _outputSubscription;
  late final StreamSubscription<Pm3ProcessState> _stateSubscription;
  Pm3ConnectionConfig? _config;
  Future<void>? _shutdownFuture;

  @override
  void updateLocalizations(AppLocalizations value) {
    super.updateLocalizations(value);
    _process.l10n = LocalizedPm3ProcessMessages(value);
  }

  /// Selects a sensible external-client default without leaking platform
  /// checks into application state or features.
  static String detectExecutable() {
    final candidates = Platform.isWindows
        ? const [
            'pm3.bat',
            'pm3.cmd',
            r'C:\proxmark3\pm3.bat',
            r'C:\proxmark3\client\proxmark3.exe',
            'proxmark3.exe',
          ]
        : const ['/usr/local/bin/proxmark3', '/usr/bin/proxmark3'];
    for (final candidate in candidates) {
      if (FileSystemEntity.isFileSync(candidate)) {
        return File(candidate).absolute.path;
      }
    }
    try {
      final lookupNames = Platform.isWindows
          ? const ['pm3.bat', 'pm3.cmd', 'proxmark3.exe']
          : const ['proxmark3'];
      for (final name in lookupNames) {
        final lookup = Process.runSync(
          Platform.isWindows ? 'where' : 'which',
          [name],
        );
        if (lookup.exitCode == 0) {
          final path =
              (lookup.stdout as String).trim().split(RegExp(r'[\r\n]+')).first;
          if (path.isNotEmpty) return path;
        }
      }
    } on ProcessException {
      // The settings page lets the user select an explicit client path.
    }
    return Platform.isWindows ? 'pm3.bat' : 'proxmark3';
  }

  @override
  Stream<Pm3Event> get events => _events.stream;
  @override
  Pm3ConnectionState get state => _mapState(_process.state);
  @override
  String get version => _process.version;
  @override
  String get lastError => _process.lastError;

  @override
  Future<void> connect(Pm3ConnectionConfig config) async {
    _config = config;
    await _process.connect(
      config.executable,
      config.port,
      arguments: config.arguments,
      workingDirectory: config.workingDirectory,
    );
  }

  @override
  Future<void> disconnect() => _process.disconnect();

  @override
  Future<Pm3Result> execute(Pm3Command command, {Duration? timeout}) async {
    if (_config == null || state != Pm3ConnectionState.connected) {
      throw StateError('PM3 is not connected');
    }
    final startedAt = DateTime.now();
    final output = await _process.sendCommandAndWait(
      command.executable,
      timeout: timeout,
    );
    return Pm3Result(
      command: command,
      output: output,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancel() async {
    if (state == Pm3ConnectionState.connected) {
      await _process.sendCommand('break');
    }
  }

  @override
  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    try {
      await _process.shutdown();
    } finally {
      try {
        await Future.wait([
          _outputSubscription.cancel(),
          _stateSubscription.cancel(),
        ]);
      } finally {
        await _events.close();
      }
    }
  }

  static Pm3ConnectionState _mapState(Pm3ProcessState state) => switch (state) {
        Pm3ProcessState.disconnected => Pm3ConnectionState.disconnected,
        Pm3ProcessState.connecting => Pm3ConnectionState.connecting,
        Pm3ProcessState.connected => Pm3ConnectionState.connected,
      };
}
