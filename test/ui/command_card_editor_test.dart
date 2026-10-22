import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/services/pm3_session_recorder.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/state/connection_state.dart' as connection;
import 'package:pm3gui/ui/widgets/command_card_editor.dart';
import '../support/localized_test_app.dart';
import '../support/file_dialogs.dart';

void main() {
  testWidgets(
      'raw command feeds editor, edit validates, navigation retains data',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppState app;
    late Directory temp;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('command-editor-');
      final responses = <String, String>{};
      final conn = connection.ConnectionState(
        controller: Pm3Controller(MockPm3Backend(responses: responses)),
        settingsStore: _Settings(),
      )
        ..pm3Path = 'mock-client'
        ..portName = 'test-port';
      app = AppState(
          connectionState: conn,
          sessionRecorder:
              Pm3SessionRecorder(rootDirectoryProvider: () async => temp));
      expect(await app.connect(), isTrue);
      // Only the user command should receive the key table, not startup hw version.
      responses['terminal.raw'] =
          '[+] 000 | 003 | A0A1A2A3A4A5 | 1 | ------------ | 0';
    });
    addTearDown(() => tester.runAsync(() async {
          await app.shutdown();
          await temp.delete(recursive: true);
        }));
    Widget editor() => ChangeNotifierProvider.value(
        value: app,
        child:
            const LocalizedTestApp(home: Scaffold(body: CommandCardEditor())));
    await tester.pumpWidget(editor());
    await tester.enterText(find.byType(TextField), 'hf mf chk --1k');
    await tester.tap(find.text('执行'));
    await tester.pumpAndSettle();
    expect(find.text('A0A1A2A3A4A5'), findsOneWidget);
    expect(app.terminalOutput.any((line) => line.contains('A0A1A2A3A4A5')),
        isTrue);
    await tester.tap(find.text('Key A'));
    await tester.pumpAndSettle();
    final field = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(field, 'BAD');
    await tester.tap(find.text('应用'));
    await tester.pump();
    expect(app.commandCard.keysA[0], 'A0A1A2A3A4A5');
    await tester.enterText(field, 'FF FF FF FF FF FF');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(app.commandCard.keysA[0], 'FFFFFFFFFFFF');
    await tester.pumpWidget(const SizedBox());
    app.navigateTo(AppPage.terminal);
    await tester.pumpWidget(editor());
    expect(find.text('FFFFFFFFFFFF'), findsOneWidget);
    await tester.tap(find.text('导出 BIN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('块 0 尚未完整'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'cancelled dialogs retain save status and opening a draft clears it across locales',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync('editor-status-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}command-card.json';
    final dialogs = TestFileDialogs()..savePath = path;
    final app = _statusApp();
    final zh = lookupAppLocalizations(const Locale('zh'));
    try {
      await _pumpEditor(tester, app, const Locale('zh'));
      await tester.tap(find.text(zh.messageSaveDraft));
      await pumpFileOperation(
          tester, () => find.text(zh.messageSaved(path)).evaluate().isNotEmpty);

      dialogs.savePath = null;
      await tester.tap(find.text(zh.messageSaveDraft));
      await tester.pumpAndSettle();
      expect(find.text(zh.messageSaved(path)), findsOneWidget);
      await tester.tap(find.text(zh.messageOpenDraft));
      await tester.pumpAndSettle();
      expect(find.text(zh.messageSaved(path)), findsOneWidget);

      await _pumpEditor(tester, app, const Locale('en'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.messageSaved(path)), findsOneWidget);
      expect(find.text(zh.messageSaved(path)), findsNothing);
      dialogs.openPath = path;
      await tester.tap(find.text(en.messageOpenDraft));
      await pumpFileOperation(
          tester, () => find.byType(SelectableText).evaluate().isEmpty);
      for (final language in ['zh', 'en']) {
        await _pumpEditor(tester, app, Locale(language));
        expect(find.byType(SelectableText), findsNothing);
        expect(app.commandCard.uid, '01020304');
      }
      expect(dialogs.calls.map((call) => call.method),
          ['getSavePath', 'getSavePath', 'openFile', 'openFile']);
    } finally {
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      await tester.pump();
    }
  });

  for (final failure in [
    'save validation',
    'save write',
    'draft import',
    'card import',
  ]) {
    testWidgets(
        '$failure replaces a save status without reviving it on locale changes',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync('editor-status-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path =
          '${directory.path}${Platform.pathSeparator}command-card.json';
      final dialogs = TestFileDialogs()..savePath = path;
      final app = _statusApp();
      final invalidCard = MifareCard(blocks: ['BAD']);
      final zh = lookupAppLocalizations(const Locale('zh'));
      try {
        await _pumpEditor(tester, app, const Locale('zh'),
            openedCard: invalidCard);
        await tester.tap(find.text(zh.messageSaveDraft));
        await pumpFileOperation(tester,
            () => find.text(zh.messageSaved(path)).evaluate().isNotEmpty);
        final saved = File(path).readAsStringSync();
        switch (failure) {
          case 'save validation':
            await tester.tap(find.text(zh.messageExportBin2));
          case 'save write':
            dialogs.savePath = directory.path;
            await tester.tap(find.text(zh.messageSaveDraft));
          case 'draft import':
            final invalidPath =
                '${directory.path}${Platform.pathSeparator}invalid.json';
            File(invalidPath).writeAsStringSync('{"format":"invalid"}');
            dialogs.openPath = invalidPath;
            await tester.tap(find.text(zh.messageOpenDraft));
          case 'card import':
            await tester.tap(find.text(zh.messageReplaceDraftWithTheOpenFile));
        }
        final errorFinder = find.byWidgetPredicate((widget) =>
            widget is SelectableText && widget.data != zh.messageSaved(path));
        await pumpFileOperation(
            tester, () => errorFinder.evaluate().isNotEmpty);
        final error = tester.widget<SelectableText>(errorFinder).data!;
        switch (failure) {
          case 'save validation':
            expect(error,
                'FormatException: ${zh.messageBlockIsIncompleteSaveADraftOr('0')}');
          case 'save write':
            expect(error, matches(r'^(?:FileSystem|PathAccess)Exception:'));
            expect(error, contains(directory.path));
          case 'draft import':
            expect(error,
                'FormatException: ${zh.messageThisIsNotACommandDataDraft}');
          case 'card import':
            expect(error,
                'FormatException: ${zh.messageEnterHexDigitsUseForUnknownDigits('32')}');
        }

        for (final language in ['en', 'zh']) {
          final l10n = lookupAppLocalizations(Locale(language));
          await _pumpEditor(tester, app, Locale(language),
              openedCard: invalidCard);
          expect(find.text(error), findsOneWidget);
          expect(find.text(l10n.messageSaved(path)), findsNothing);
          expect(app.commandCard.exportDraft(), saved);
        }
        final recoveryPath =
            '${directory.path}${Platform.pathSeparator}recovered.json';
        dialogs.savePath = recoveryPath;
        await tester.tap(find.text(zh.messageSaveDraft));
        await pumpFileOperation(
            tester,
            () =>
                find.text(zh.messageSaved(recoveryPath)).evaluate().isNotEmpty);
        expect(find.text(error), findsNothing);
        await _pumpEditor(tester, app, const Locale('en'),
            openedCard: invalidCard);
        final en = lookupAppLocalizations(const Locale('en'));
        expect(find.text(en.messageSaved(recoveryPath)), findsOneWidget);
        expect(find.text(en.messageSaved(path)), findsNothing);
        expect(find.text(error), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        app.dispose();
        await tester.pump();
      }
    });
  }
}

AppState _statusApp() => _OfflineAppState(
      connectionState: connection.ConnectionState(
        controller: Pm3Controller(MockPm3Backend()),
        settingsStore: _Settings(),
      ),
    )..commandCard.uid = '01020304';

Future<void> _pumpEditor(WidgetTester tester, AppState app, Locale locale,
    {MifareCard? openedCard}) async {
  app.updateLocalizations(lookupAppLocalizations(locale));
  await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
    value: app,
    child: LocalizedTestApp(
      locale: locale,
      home: Scaffold(body: CommandCardEditor(openedCard: openedCard)),
    ),
  ));
  await tester.pumpAndSettle();
}

class _OfflineAppState extends AppState {
  _OfflineAppState({required super.connectionState});

  @override
  Future<void> scanForFiles() async {}
}

class _Settings implements Pm3SettingsRepository {
  @override
  Future<Pm3ClientSettings?> load() async => null;
  @override
  Future<void> save(Pm3ClientSettings settings) async {}
}
