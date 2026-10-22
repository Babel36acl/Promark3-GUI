import 'dart:async';

import 'pm3_backend.dart';
import 'pm3_command.dart';
import 'pm3_connection.dart';
import 'pm3_event.dart';
import 'pm3_result.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

/// The only PM3 entry point exposed to application and feature layers.
final class Pm3Controller with LocalizedMessages {
  Pm3Controller(this._backend);

  final Pm3Backend _backend;

  @override
  void updateLocalizations(AppLocalizations value) {
    super.updateLocalizations(value);
    if (_backend case final LocalizedMessages backend) {
      backend.updateLocalizations(value);
    }
  }

  final StreamController<Pm3Command> _commands =
      StreamController<Pm3Command>.broadcast(sync: true);
  Future<void>? _shutdownFuture;
  bool _isExecuting = false;
  bool get isExecuting => _isExecuting;

  Stream<Pm3Event> get events => _backend.events;
  Stream<Pm3Command> get commands => _commands.stream;
  Stream<String> get outputLines => events
      .where((event) => event is Pm3OutputEvent)
      .cast<Pm3OutputEvent>()
      .map((event) => event.line);
  Stream<Pm3ConnectionState> get stateChanges => events
      .where((event) => event is Pm3StateChangedEvent)
      .cast<Pm3StateChangedEvent>()
      .map((event) => event.state);
  Pm3ConnectionState get state => _backend.state;
  String get version => _backend.version;
  String get lastError => _backend.lastError;
  bool get isConnected => state == Pm3ConnectionState.connected;

  Future<bool> connect(Pm3ConnectionConfig config) async {
    await _backend.connect(config);
    return isConnected;
  }

  Future<void> disconnect() => _backend.disconnect();

  Future<Pm3Result> execute(Pm3Command command, {Duration? timeout}) async {
    if (_isExecuting) throw StateError(l10n.pm3Busy);
    _isExecuting = true;
    try {
      _commands.add(command);
      return await _backend.execute(command, timeout: timeout);
    } finally {
      _isExecuting = false;
    }
  }

  Future<void> send(String command) async {
    await execute(Pm3Command(id: 'terminal.raw', executable: command));
  }

  Future<void> cancel() => _backend.cancel();

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    try {
      await _commands.close();
    } finally {
      await _backend.shutdown();
    }
  }

  void dispose() {
    unawaited(shutdown());
  }
}
