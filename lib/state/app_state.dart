import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/models/command_card.dart';
import 'package:pm3gui/services/file_collector.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/services/pm3_session_recorder.dart';
import 'package:pm3gui/state/connection_state.dart';
import 'package:pm3gui/state/terminal_state.dart';
import 'package:pm3gui/state/file_state.dart';
import 'package:pm3gui/state/hardware_state.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

enum AppPage {
  connection,
  terminal,
  dumpViewer,
  dumpCompare,
  mifare,
  mifareUltralight,
  desfire,
  iclass,
  iso15693,
  iso14443b,
  felica,
  legic,
  emv,
  seos,
  fido,
  hfSniff,
  lf,
  lfHid,
  lfHitag,
  lfAwid,
  lfIndala,
  lfIo,
  lfPyramid,
  lfKeri,
  lfFdxb,
  data,
  trace,
  nfc,
  script,
  settings,
}

class NavigationIntent {
  final AppPage page;
  final String action;
  final Map<String, String> params;
  final int timestamp;

  const NavigationIntent({
    required this.page,
    required this.action,
    this.params = const {},
    required this.timestamp,
  });
}

enum WriteStatus { idle, writing, finished, cancelled, connectionLost }

class WriteProgress {
  final int total;
  int completed;
  int succeeded;
  int failed;
  WriteStatus status;
  int currentBlock;
  final List<WriteBlockResult> results;

  WriteProgress({
    required this.total,
    this.completed = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.status = WriteStatus.idle,
    this.currentBlock = 0,
    List<WriteBlockResult>? results,
  }) : results = results ?? [];

  double get progress => total > 0 ? completed / total : 0;
  bool get cancelled =>
      status == WriteStatus.cancelled || status == WriteStatus.connectionLost;
  bool get isRunning => !cancelled && completed < total;

  String localizedStatus(AppLocalizations l10n) => switch (status) {
        WriteStatus.idle => '',
        WriteStatus.writing =>
          l10n.messageWritingBlock(currentBlock.toString()),
        WriteStatus.finished => l10n.messageFinishedSucceededFailed(
            succeeded.toString(), failed.toString()),
        WriteStatus.cancelled => l10n.messageCancelled,
        WriteStatus.connectionLost =>
          l10n.messageConnectionLostOperationAborted,
      };
}

class WriteBlockResult {
  final int block;
  final bool success;
  const WriteBlockResult({
    required this.block,
    required this.success,
  });

  String localizedMessage(AppLocalizations l10n) => success
      ? l10n.messageWriteSuccessful
      : l10n.messageAuthenticationOrWritingFailed;
}

class AppState extends ChangeNotifier with LocalizedMessages {
  late final ConnectionState connectionState;
  late final TerminalState terminalState;
  late final FileState fileState;
  late final HardwareState hardwareState;
  final Pm3SessionRecorder _sessionRecorder;
  late final StreamSubscription<String> _outputSubscription;
  late final StreamSubscription _commandSubscription;
  late final StreamSubscription<Pm3ConnectionState> _stateSubscription;
  StreamSubscription<String>? _hwVersionOutputSubscription;
  Timer? _hwVersionTimer;
  Future<void> _sessionClose = Future.value();
  Future<void>? _shutdownFuture;
  bool _disconnectInProgress = false;
  bool _resourcesReleased = false;
  bool _notifierDisposed = false;
  String? _sessionLogError;

  int currentPageIndex = 0;
  NavigationIntent? _pendingIntent;
  NavigationIntent? get pendingIntent => _pendingIntent;

  MifareCard currentCard = MifareCard();
  final commandCard = CommandCard();

  @override
  void updateLocalizations(AppLocalizations value) {
    super.updateLocalizations(value);
    connectionState.updateLocalizations(value);
    fileState.updateLocalizations(value);
    hardwareState.updateLocalizations(value);
    commandCard.updateLocalizations(value);
  }

  WriteProgress? writeProgress;

  String? preferredMfKeyFile;
  String? preferredMfDumpFile;

  bool get isConnected => connectionState.isConnected;
  String get lastError => connectionState.lastError;
  String get pm3Version => connectionState.pm3Version;
  String? get sessionLogError => _sessionLogError;
  bool get isSavingSettings => connectionState.isSavingSettings;
  String? get settingsError => connectionState.settingsError;

  String get pm3Path => connectionState.pm3Path;
  set pm3Path(String value) => connectionState.setPm3Path(value);

  String get portName => connectionState.portName;
  set portName(String value) => connectionState.setPort(value);

  List<String> get pm3Arguments => connectionState.pm3Arguments;
  String? get pm3WorkingDirectory => connectionState.pm3WorkingDirectory;

  List<String> get availablePorts => connectionState.availablePorts;
  set availablePorts(List<String> value) =>
      connectionState.setAvailablePorts(value);

  List<String> get terminalOutput => terminalState.terminalOutput;
  List<String> get terminalOutputStripped =>
      terminalState.terminalOutputStripped;
  List<String> get terminalOutputRaw => terminalState.terminalOutputRaw;
  int get outputRevision => terminalState.outputRevision;
  List<String> get commandHistory => terminalState.commandHistory;
  int get historyIndex => terminalState.historyIndex;
  set historyIndex(int value) => terminalState.setHistoryIndex(value);

  List<CollectedFile> get collectedFiles => fileState.collectedFiles;
  List<CardGroup> get cardGroups => fileState.cardGroups;
  bool get isScanning => fileState.isScanning;
  String? get collectBaseDir => fileState.collectBaseDir;

  String get hwModel => hardwareState.hwModel;
  String get hwFirmware => hardwareState.hwFirmware;
  String get hwBootrom => hardwareState.hwBootrom;
  String get hwMcu => hardwareState.hwMcu;
  String get hwFlashSize => hardwareState.hwFlashSize;
  String get hwSmartcard => hardwareState.hwSmartcard;
  String get hwFpga => hardwareState.hwFpga;
  String get hwUniqueId => hardwareState.hwUniqueId;
  int get hwFlashFree => hardwareState.hwFlashFree;
  int get hwFlashTotal => hardwareState.hwFlashTotal;
  bool get hwInfoParsed => hardwareState.hwInfoParsed;

  Stream<String> get pm3Output => connectionState.controller.outputLines;
  final _connectionOutput = StringBuffer();

  /// 子终端接收当前页面的实时输出，切换页面即关闭；总终端独立订阅。
  Stream<String> get pm3PageOutput {
    final pageIndex = currentPageIndex;
    late StreamController<String> output;
    StreamSubscription<String>? subscription;
    void pageChanged() {
      if (currentPageIndex != pageIndex) unawaited(output.close());
    }

    output = StreamController<String>(
      sync: true,
      onListen: () {
        addListener(pageChanged);
        subscription = pm3Output.listen((line) {
          if (!output.isClosed) output.add(line);
        }, onError: (Object error, StackTrace stack) {
          if (!output.isClosed) output.addError(error, stack);
        }, onDone: output.close);
      },
      onCancel: () async {
        removeListener(pageChanged);
        await subscription?.cancel();
      },
    );
    return output.stream;
  }

  AppState({
    ConnectionState? connectionState,
    Pm3SessionRecorder? sessionRecorder,
  }) : _sessionRecorder = sessionRecorder ?? Pm3SessionRecorder() {
    this.connectionState = connectionState ?? ConnectionState();
    terminalState = TerminalState();
    fileState = FileState();
    hardwareState = HardwareState();

    this.connectionState.addListener(_onConnectionChanged);
    unawaited(initialize());

    // Propagate terminal state changes so widgets depending on AppState
    // (via context.select on outputRevision / terminalOutput) will rebuild
    // in real-time when TerminalState notifies.
    terminalState.addListener(_onTerminalChanged);
    _outputSubscription =
        this.connectionState.controller.outputLines.listen((line) {
      if (this.connectionState.controller.state ==
          Pm3ConnectionState.connecting) {
        _connectionOutput.writeln(line);
      }
      commandCard.consume(line);
      terminalState.addOutput(line);
      _recordSession(_sessionRecorder.recordOutput(line));

      if (line.toLowerCase().contains('saved') ||
          line.toLowerCase().contains('saved to')) {
        Future.delayed(const Duration(seconds: 1), () => scanForFiles());
      }
    });

    _commandSubscription =
        this.connectionState.controller.commands.listen((command) {
      commandCard.beginCommand(command.executable);
      _recordSession(_sessionRecorder.recordCommand(command.executable));
    });

    _stateSubscription =
        this.connectionState.controller.stateChanges.listen((state) {
      if (state == Pm3ConnectionState.connecting) {
        _connectionOutput.clear();
      } else if (state == Pm3ConnectionState.connected) {
        _recordSession(_sessionRecorder.start(
          devicePort: this.connectionState.portName,
          executable: this.connectionState.pm3Path,
        ));
        scanForFiles();
        _queryHwVersion(
          sendCommand: !this.connectionState.usesWindowsBatchClient,
        );
      } else if (state == Pm3ConnectionState.disconnected) {
        commandCard.beginCommand('');
        if (!_disconnectInProgress) {
          _sessionClose = _recordSession(_sessionRecorder.close());
        }
        hardwareState.resetHwInfo();
      }
      _notifyListenersIfActive();
    });
  }

  void _onTerminalChanged() {
    // Forward terminal state changes to AppState listeners.
    _notifyListenersIfActive();
  }

  void _onConnectionChanged() {
    _notifyListenersIfActive();
  }

  Future<void> initialize() => connectionState.initialize();

  Future<bool> connect() async {
    hardwareState.resetHwInfo();
    final result = await connectionState.connect();
    notifyListeners();
    return result;
  }

  Future<void> disconnect() async {
    await _disconnectAndCloseSession();
    hardwareState.resetHwInfo();
    notifyListeners();
  }

  Future<void> sendCommand(String cmd) async {
    terminalState.addCommand(cmd);
    try {
      await connectionState.sendCommand(cmd);
    } catch (error) {
      terminalState.addOutput(l10n.messageError((error).toString()));
    }
  }

  Future<WriteProgress> sendCommandSequence(
    List<(int block, String cmd)> commands, {
    Duration delayBetween = const Duration(milliseconds: 800),
  }) async {
    final progress = WriteProgress(total: commands.length);
    writeProgress = progress;
    notifyListeners();

    for (final (block, cmd) in commands) {
      if (progress.cancelled) break;
      if (!isConnected) {
        progress.status = WriteStatus.connectionLost;
        notifyListeners();
        break;
      }

      progress
        ..status = WriteStatus.writing
        ..currentBlock = block;
      notifyListeners();

      await sendCommand(cmd);
      await Future.delayed(delayBetween);

      final lastLines = terminalState.terminalOutput.length > 3
          ? terminalState.terminalOutput
              .sublist(terminalState.terminalOutput.length - 3)
          : terminalState.terminalOutput;
      final fail = lastLines
          .any((l) => l.contains('( fail )') || l.contains('Auth error'));

      if (fail) {
        progress.failed++;
        progress.results.add(WriteBlockResult(
          block: block,
          success: false,
        ));
      } else {
        progress.succeeded++;
        progress.results.add(WriteBlockResult(
          block: block,
          success: true,
        ));
      }
      progress.completed++;
      notifyListeners();
    }

    if (!progress.cancelled) {
      progress.status = WriteStatus.finished;
    }
    notifyListeners();
    return progress;
  }

  void cancelWriteSequence() {
    if (writeProgress != null && writeProgress!.isRunning) {
      writeProgress!.status = WriteStatus.cancelled;
      notifyListeners();
    }
  }

  Future<void> setPort(String port) {
    return connectionState.setPort(port);
  }

  Future<void> setPm3Path(String path) {
    return connectionState.setPm3Path(path);
  }

  Future<void> setPm3Arguments(List<String> arguments) {
    return connectionState.setPm3Arguments(arguments);
  }

  Future<void> setPm3WorkingDirectory(String? workingDirectory) {
    return connectionState.setPm3WorkingDirectory(workingDirectory);
  }

  void clearTerminal() {
    terminalState.clearTerminal();
  }

  void setCurrentPage(int index) {
    if (index == currentPageIndex) return;
    currentPageIndex = index;
    notifyListeners();
  }

  void navigateTo(AppPage page) {
    setCurrentPage(page.index);
  }

  void requestNavigationIntent(
    AppPage page, {
    required String action,
    Map<String, String> params = const {},
  }) {
    currentPageIndex = page.index;
    _pendingIntent = NavigationIntent(
      page: page,
      action: action,
      params: params,
      timestamp: DateTime.now().microsecondsSinceEpoch,
    );
    notifyListeners();
  }

  NavigationIntent? takePendingIntentFor(AppPage page) {
    final intent = _pendingIntent;
    if (intent == null || intent.page != page) return null;
    _pendingIntent = null;
    return intent;
  }

  void requestOpenDumpInViewer(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return;

    preferredMfDumpFile = normalized;
    requestNavigationIntent(
      AppPage.dumpViewer,
      action: 'open_file',
      params: {'path': normalized},
    );
  }

  void updateCard(MifareCard card) {
    currentCard = card;
    notifyListeners();
  }

  void setPreferredMfKeyFile(String? path) {
    preferredMfKeyFile = (path != null && path.trim().isNotEmpty) ? path : null;
    notifyListeners();
  }

  void setPreferredMfDumpFile(String? path) {
    preferredMfDumpFile =
        (path != null && path.trim().isNotEmpty) ? path : null;
    notifyListeners();
  }

  void setCollectBaseDir(String? baseDir) {
    fileState.setCollectBaseDir(baseDir);
    notifyListeners();
  }

  Future<void> scanForFiles() async {
    await fileState.scanForFiles(connectionState.pm3Path,
        workingDirectory: connectionState.pm3WorkingDirectory);
    _notifyListenersIfActive();
  }

  Future<int> organizeCollectedFiles(String baseDir) async {
    final count = await fileState.organizeCollectedFiles(baseDir);
    notifyListeners();
    return count;
  }

  void _queryHwVersion({bool sendCommand = true}) {
    if (!sendCommand) {
      hardwareState.parseHwVersion(_connectionOutput.toString());
      _connectionOutput.clear();
      _notifyListenersIfActive();
      return;
    }
    final buffer = StringBuffer();
    unawaited(_hwVersionOutputSubscription?.cancel() ?? Future.value());
    _hwVersionTimer?.cancel();
    final subscription = connectionState.controller.outputLines.listen((line) {
      buffer.writeln(line);
    });
    _hwVersionOutputSubscription = subscription;

    if (sendCommand) connectionState.controller.send('hw version');

    _hwVersionTimer = Timer(const Duration(seconds: 3), () {
      unawaited(subscription.cancel());
      if (identical(_hwVersionOutputSubscription, subscription)) {
        _hwVersionOutputSubscription = null;
      }
      hardwareState.parseHwVersion(buffer.toString());
      _notifyListenersIfActive();
    });
  }

  /// Completes after settings, Session queue, subscriptions and the PM3 backend
  /// have all been released.
  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    try {
      await connectionState.flushSettings();
      await _disconnectAndCloseSession();
    } finally {
      await _releaseResources();
    }
  }

  Future<void> _disconnectAndCloseSession() async {
    _disconnectInProgress = true;
    try {
      await connectionState.disconnect();
    } finally {
      _disconnectInProgress = false;
      _sessionClose = _recordSession(_sessionRecorder.close());
      await _sessionClose;
    }
  }

  Future<void> _releaseResources() async {
    if (_resourcesReleased) return;
    _resourcesReleased = true;
    _hwVersionTimer?.cancel();
    _hwVersionTimer = null;
    final hwVersionOutputSubscription = _hwVersionOutputSubscription;
    _hwVersionOutputSubscription = null;
    try {
      terminalState.removeListener(_onTerminalChanged);
    } catch (_) {}
    connectionState.removeListener(_onConnectionChanged);
    try {
      await Future.wait([
        _outputSubscription.cancel(),
        _commandSubscription.cancel(),
        _stateSubscription.cancel(),
        if (hwVersionOutputSubscription != null)
          hwVersionOutputSubscription.cancel(),
      ]);
    } finally {
      try {
        await connectionState.shutdown();
      } finally {
        connectionState.dispose();
        _disposeNotifier();
      }
    }
  }

  Future<void> _recordSession(Future<void> operation) {
    return operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        _sessionLogError = error.toString();
        _notifyListenersIfActive();
      },
    );
  }

  void _notifyListenersIfActive() {
    if (!_notifierDisposed) notifyListeners();
  }

  void _disposeNotifier() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    super.dispose();
  }

  Future<void> refreshHwInfo() async {
    if (!isConnected) return;
    _queryHwVersion();
  }

  @override
  void dispose() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    super.dispose();
    unawaited(shutdown());
  }
}
