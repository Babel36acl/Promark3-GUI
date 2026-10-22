import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/core/pm3/pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/core/pm3/pm3_command.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart' as pm3;
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/core/pm3/pm3_event.dart';
import 'package:pm3gui/core/pm3/pm3_result.dart';
import 'package:pm3gui/services/pm3_command_catalog.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/state/connection_state.dart' as connection;
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import '../support/localized_test_app.dart';

void main() {
  testWidgets(
      'one click streams immediately beyond five seconds until page switch',
      (tester) async {
    late _StreamingBackend backend;
    late AppState state;
    await tester.runAsync(() async {
      backend = _StreamingBackend();
      state = AppState(
          connectionState: connection.ConnectionState(
        controller: Pm3Controller(backend),
        settingsStore: _Settings(),
      ));
      await state.initialize();
    });
    state.navigateTo(AppPage.mifareUltralight);
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const LocalizedTestApp(home: Scaffold(body: HfMfuPage())),
    ));
    await tester.tap(find.text('获取信息'));
    await tester.pump();
    expect(backend.commands, ['hf mfu info']);
    expect(find.textContaining('FIRST_ROW'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    backend.emit('LATE_ROW');
    await tester.pump();
    expect(find.textContaining('LATE_ROW'), findsOneWidget);
    // A second click must not cancel the current capture or dispatch twice.
    await tester.tap(find.text('获取信息'));
    await tester.pump();
    expect(backend.commands, hasLength(1));
    backend.done.complete();
    await tester.pump();
    backend.emit('AFTER_COMPLETION');
    await tester.pump();
    expect(find.textContaining('AFTER_COMPLETION'), findsOneWidget);

    state.navigateTo(AppPage.terminal);
    await tester.pump();
    backend.emit('OTHER_PAGE_ROW');
    await tester.pump();
    expect(find.textContaining('OTHER_PAGE_ROW'), findsNothing);
    expect(state.terminalOutput, contains('OTHER_PAGE_ROW'));
    state.navigateTo(AppPage.mifareUltralight);
    backend.emit('STILL_DETACHED');
    await tester.pump();
    expect(find.textContaining('STILL_DETACHED'), findsNothing);
    expect(state.terminalOutput, contains('STILL_DETACHED'));
    await tester.pumpWidget(const SizedBox());
    backend.emit('AFTER_DISPOSE');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.runAsync(state.shutdown);
  });

  testWidgets(
      'catalog includes installed client commands and retains localized entries',
      (tester) async {
    final entries = (await tester.runAsync(() => Pm3CommandCatalog.load()))!;
    final commands = entries.map((e) => e.command).toSet();
    expect(
        commands,
        containsAll(
            ['hf mf sen', 'hf mf gdmgetcfg', 'hf mf madread', 'hf mf wrbl']));
    expect(entries.where((e) => e.command == 'hf 14a info'), hasLength(1));
    expect(entries.firstWhere((e) => e.command == 'hf 14a info').description,
        contains('用法'));
  });
}

class _Settings implements Pm3SettingsRepository {
  @override
  Future<Pm3ClientSettings?> load() async => null;
  @override
  Future<void> save(Pm3ClientSettings settings) async {}
}

class _StreamingBackend implements Pm3Backend {
  final _events = StreamController<Pm3Event>.broadcast(sync: true);
  final commands = <String>[];
  final done = Completer<void>();
  void emit(String line) => _events.add(Pm3OutputEvent(DateTime.now(), line));
  @override
  Stream<Pm3Event> get events => _events.stream;
  @override
  pm3.Pm3ConnectionState get state => pm3.Pm3ConnectionState.connected;
  @override
  String get version => 'test';
  @override
  String get lastError => '';
  @override
  Future<void> connect(pm3.Pm3ConnectionConfig config) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<void> shutdown() => _events.close();
  @override
  Future<Pm3Result> execute(Pm3Command command, {Duration? timeout}) async {
    commands.add(command.executable);
    final started = DateTime.now();
    emit('FIRST_ROW');
    await done.future;
    return Pm3Result(
        command: command,
        output: 'FIRST_ROW\nLATE_ROW',
        startedAt: started,
        finishedAt: DateTime.now());
  }
}
