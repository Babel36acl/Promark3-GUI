import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/backend/desktop_cli/desktop_cli_backend.dart';
import 'package:pm3gui/backend/desktop_cli/pm3_process.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/l10n/app_locale_controller.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/main.dart';
import 'package:pm3gui/models/dump_analysis.dart';
import 'package:pm3gui/parsers/dump_parser.dart';
import 'package:pm3gui/services/dump_converter.dart';
import 'package:pm3gui/services/pm3_command_catalog.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/services/locale_settings_store.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/state/connection_state.dart' as connection;
import '../support/localized_test_app.dart';
import '../support/file_dialogs.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('all pages render in $language without layout errors',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _appState();
      final locale =
          AppLocaleController(repository: MemoryLocaleSettings(language));
      final initialized = Future.wait([app.initialize(), locale.initialize()]);
      await tester.pump();
      await initialized;
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app,
        child: DefaultAssetBundle(
          bundle: _CatalogBundle(),
          child: PM3GuiApp(localeController: locale),
        ),
      ));
      await _render(tester);
      for (final page in AppPage.values) {
        app.navigateTo(page);
        await _render(tester);
        expect(tester.takeException(), isNull,
            reason: '$language / ${page.name}');
        final tabBars = find.byType(TabBar);
        if (tabBars.evaluate().isNotEmpty) {
          final tabs =
              find.descendant(of: tabBars.first, matching: find.byType(Tab));
          final count = tabs.evaluate().length;
          for (var index = 0; index < count; index++) {
            await tester.tap(tabs.at(index));
            await _render(tester);
            expect(tester.takeException(), isNull,
                reason: '$language / ${page.name} / tab $index');
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      await tester.pump();
      locale.dispose();
    });
  }

  testWidgets(
      'language picker switches immediately, preserves data and saves selection',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryLocaleSettings('zh');
    final locale = AppLocaleController(repository: repository);
    final app = _appState();
    final initialized = Future.wait([app.initialize(), locale.initialize()]);
    await tester.pump();
    await initialized;
    app.commandCard.uid = '01020304';
    app.navigateTo(AppPage.settings);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: DefaultAssetBundle(
        bundle: _CatalogBundle(),
        child: PM3GuiApp(localeController: locale),
      ),
    ));
    await _render(tester);
    expect(find.text('语言'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('language-zh')));
    await _render(tester);
    await tester.tap(find.text('English').last);
    await _render(tester);
    expect(find.text('Language'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('语言'), findsNothing);
    expect(repository.language, 'en');
    expect(app.commandCard.uid, '01020304');
    expect(
        () => app.commandCard.editBlock(-1, ''),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'localized message', contains('Block number'))));
    await tester.tap(find.byKey(const ValueKey('language-en')));
    await _render(tester);
    await tester.tap(find.text('简体中文').last);
    await _render(tester);
    expect(find.text('语言'), findsWidgets);
    expect(repository.language, 'zh');
    await tester.pumpWidget(const SizedBox());
    app.dispose();
    await tester.pump();
    locale.dispose();
  });

  testWidgets(
      'directory lookup failure still allows startup and a Settings error',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _appState();
    final locale = AppLocaleController(
      repository: LocaleSettingsStore(
        directoryProvider: () async => throw MissingPlatformDirectoryException(
            'support directory unavailable'),
      ),
    );
    try {
      final initialized = Future.wait([app.initialize(), locale.initialize()]);
      final initialization = expectLater(initialized, completes);
      await tester.pump();
      await initialization;
      app.navigateTo(AppPage.settings);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: app,
        child: DefaultAssetBundle(
          bundle: _CatalogBundle(),
          child: PM3GuiApp(localeController: locale),
        ),
      ));
      await _render(tester);

      expect(find.byKey(const ValueKey('language-error')), findsOneWidget);
      expect(
          find.textContaining('support directory unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      await tester.pump();
      locale.dispose();
    }
  });

  testWidgets(
      'connection failure follows Settings language without retrying or rewriting terminal output',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var starts = 0;
    final process = Pm3Process(
      processStarter: (_, __, {workingDirectory}) async {
        starts++;
        throw StateError('A missing client must not be started');
      },
    );
    final backend = DesktopCliBackend(process: process);
    final app = _OfflineAppState(
      connectionState: connection.ConnectionState(
        controller: Pm3Controller(backend),
        settingsStore: _Settings(),
      ),
    );
    final locale = AppLocaleController(repository: MemoryLocaleSettings('zh'));
    final initialized = Future.wait([app.initialize(), locale.initialize()]);
    await tester.pump();
    await initialized;
    final path = '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'pm3gui-missing-${DateTime.now().microsecondsSinceEpoch}.exe';
    expect(File(path).existsSync(), isFalse);
    app.connectionState
      ..pm3Path = path
      ..portName = 'test';
    final states = <Pm3ProcessState>[];
    final subscription = process.stateStream.listen(states.add);
    addTearDown(subscription.cancel);
    try {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: DefaultAssetBundle(
          bundle: _CatalogBundle(),
          child: PM3GuiApp(localeController: locale),
        ),
      ));
      await _render(tester);
      final connecting = app.connect();
      await tester.pump();
      expect(await connecting, isFalse);
      await _render(tester);
      final chinese = lookupAppLocalizations(const Locale('zh'));
      expect(find.text(chinese.messagePm3ProgramNotFoundOnWindowsSelect(path)),
          findsOneWidget);
      final terminal = app.terminalOutput.toList();
      final history = app.commandHistory.toList();
      expect(terminal, [
        chinese.messageError(
            chinese.messagePm3ProgramNotFoundOnWindowsSelect(path)),
      ]);

      for (final language in ['en', 'zh']) {
        final l10n = lookupAppLocalizations(Locale(language));
        final other =
            lookupAppLocalizations(Locale(language == 'en' ? 'zh' : 'en'));
        app.navigateTo(AppPage.settings);
        await _render(tester);
        await tester.tap(
            find.byKey(ValueKey('language-${locale.locale!.languageCode}')));
        await _render(tester);
        await tester.tap(find.text(language == 'en' ? 'English' : '简体中文').last);
        await _render(tester);
        app.navigateTo(AppPage.connection);
        await _render(tester);

        final expected = l10n.messagePm3ProgramNotFoundOnWindowsSelect(path);
        expect(find.text(expected), findsOneWidget);
        expect(find.text(other.messagePm3ProgramNotFoundOnWindowsSelect(path)),
            findsNothing);
        expect(app.lastError, expected);
        expect(app.isConnected, isFalse);
        expect(app.pm3Path, path);
        expect(app.terminalOutput, orderedEquals(terminal));
        expect(app.commandHistory, orderedEquals(history));
        expect(
            states, [Pm3ProcessState.connecting, Pm3ProcessState.disconnected]);
        expect(starts, 0);
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      await tester.pump();
      locale.dispose();
    }
  });

  for (final status in [
    WriteStatus.writing,
    WriteStatus.finished,
    WriteStatus.cancelled,
    WriteStatus.connectionLost,
  ]) {
    testWidgets(
        '${status.name} write progress and results follow Settings language changes',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dump = (await tester.runAsync(() async {
        final directory =
            await Directory.systemTemp.createTemp('pm3-write-locale-');
        addTearDown(() => directory.delete(recursive: true));
        return File('${directory.path}${Platform.pathSeparator}sample.bin')
          ..writeAsBytesSync(Uint8List(1024));
      }))!;
      final app = _appState();
      final locale =
          AppLocaleController(repository: MemoryLocaleSettings('zh'));
      final initialized = Future.wait([app.initialize(), locale.initialize()]);
      await tester.pump();
      await initialized;
      final progress = WriteProgress(
        total: status == WriteStatus.finished ? 2 : 4,
        completed: 2,
        succeeded: 1,
        failed: 1,
        status: status,
        currentBlock: 9,
        results: const [
          WriteBlockResult(block: 4, success: true),
          WriteBlockResult(block: 7, success: false),
        ],
      );
      final results = progress.results.toList();
      app.writeProgress = progress;
      app.terminalState.addOutput('Auth error - 原始输出');
      app.requestNavigationIntent(
        AppPage.dumpViewer,
        action: 'open_file',
        params: {'path': dump.path},
      );
      try {
        await tester.pumpWidget(ChangeNotifierProvider.value(
          value: app,
          child: DefaultAssetBundle(
            bundle: _CatalogBundle(),
            child: PM3GuiApp(localeController: locale),
          ),
        ));
        for (var attempt = 0;
            attempt < 100 && app.preferredMfDumpFile != dump.path;
            attempt++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump();
        }
        expect(app.preferredMfDumpFile, dump.path);
        await _render(tester);
        final zh = lookupAppLocalizations(const Locale('zh'));
        await tester.tap(find.text(zh.messageWriteClear));
        await tester.pumpAndSettle();

        for (final language in ['zh', 'en', 'zh']) {
          final l10n = lookupAppLocalizations(Locale(language));
          final other =
              lookupAppLocalizations(Locale(language == 'en' ? 'zh' : 'en'));
          if (locale.locale?.languageCode != language) {
            app.navigateTo(AppPage.settings);
            await _render(tester);
            final currentLanguage = locale.locale!.languageCode;
            await tester.tap(find.byKey(ValueKey('language-$currentLanguage')));
            await _render(tester);
            await tester
                .tap(find.text(language == 'en' ? 'English' : '简体中文').last);
            await _render(tester);
            app.navigateTo(AppPage.dumpViewer);
            await _render(tester);
          }
          await tester.ensureVisible(find.text(l10n.messageWriteProgress));
          await _render(tester);
          expect(find.text(progress.localizedStatus(l10n)), findsOneWidget);
          expect(find.text(l10n.messageWriteSuccessful), findsOneWidget);
          expect(find.text(l10n.messageAuthenticationOrWritingFailed),
              findsOneWidget);
          expect(find.text(progress.localizedStatus(other)), findsNothing);
          expect(find.text(other.messageWriteSuccessful), findsNothing);
          expect(find.text(other.messageAuthenticationOrWritingFailed),
              findsNothing);
          expect(app.writeProgress, same(progress));
          expect(progress.status, status);
          expect(progress.completed, 2);
          expect(progress.succeeded, 1);
          expect(progress.failed, 1);
          expect(progress.results, orderedEquals(results));
          expect(progress.results.map((r) => r.block), [4, 7]);
          expect(app.preferredMfDumpFile, dump.path);
          expect(app.terminalOutput, contains('Auth error - 原始输出'));
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        app.dispose();
        await tester.pump();
        locale.dispose();
      }
    });
  }

  testWidgets(
      'editor save status follows Settings language without saving again',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync('editor-locale-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}command-card.json';
    final dialogs = TestFileDialogs()..savePath = path;
    final app = _appState();
    final locale = AppLocaleController(repository: MemoryLocaleSettings('zh'));
    final initialized = Future.wait([app.initialize(), locale.initialize()]);
    await tester.pump();
    await initialized;
    app.commandCard.uid = '01020304';
    app.navigateTo(AppPage.dumpViewer);
    final zh = lookupAppLocalizations(const Locale('zh'));
    try {
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: app,
        child: DefaultAssetBundle(
          bundle: _CatalogBundle(),
          child: PM3GuiApp(localeController: locale),
        ),
      ));
      await _render(tester);
      await tester.tap(find.descendant(
          of: find.byType(TabBar), matching: find.text(zh.messageCommandData)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(zh.messageSaveDraft));
      await pumpFileOperation(
          tester, () => find.text(zh.messageSaved(path)).evaluate().isNotEmpty);
      final saved = File(path).readAsStringSync();
      final modified = File(path).lastModifiedSync();
      final draft = app.commandCard;
      for (final language in ['en', 'zh']) {
        app.navigateTo(AppPage.settings);
        await _render(tester);
        await tester.tap(
            find.byKey(ValueKey('language-${locale.locale!.languageCode}')));
        await _render(tester);
        await tester.tap(find.text(language == 'en' ? 'English' : '简体中文').last);
        await _render(tester);
        app.navigateTo(AppPage.dumpViewer);
        await _render(tester);
        final l10n = lookupAppLocalizations(Locale(language));
        final other =
            lookupAppLocalizations(Locale(language == 'en' ? 'zh' : 'en'));
        expect(find.text(l10n.messageSaved(path)), findsOneWidget);
        expect(find.text(other.messageSaved(path)), findsNothing);
        expect(app.commandCard, same(draft));
        expect(app.commandCard.uid, '01020304');
        expect(File(path).readAsStringSync(), saved);
        expect(File(path).lastModifiedSync(), modified);
        expect(dialogs.calls.map((call) => call.method), ['getSavePath']);
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      app.dispose();
      await tester.pump();
      locale.dispose();
    }
  });

  for (final systemLocale in [
    const Locale('fr', 'FR'),
    const Locale('zh', 'CN'),
    const Locale('en', 'GB')
  ]) {
    testWidgets('system locale $systemLocale resolves to a supported language',
        (tester) async {
      tester.binding.platformDispatcher.localesTestValue = [systemLocale];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Text(context.l10n.navSettings)),
      ));
      await tester.pumpAndSettle();
      expect(find.text(systemLocale.languageCode == 'zh' ? '设置' : 'Settings'),
          findsOneWidget);
      final context = tester.element(find.byType(Text).last);
      final material = MaterialLocalizations.of(context);
      expect(material.cancelButtonLabel,
          systemLocale.languageCode == 'zh' ? '取消' : 'Cancel');
    });
  }

  testWidgets(
      'command descriptions follow the language without changing command syntax',
      (tester) async {
    final zh =
        await Pm3CommandCatalog.load(preferZh: true, bundle: _CatalogBundle());
    final en =
        await Pm3CommandCatalog.load(preferZh: false, bundle: _CatalogBundle());
    final zhCommands = zh.map((e) => e.command).toSet();
    final enCommands = en.map((e) => e.command).toSet();
    expect(enCommands, zhCommands);
    final chinese = zh.firstWhere((e) => e.command == 'hf 14a info');
    final english = en.firstWhere((e) => e.command == 'hf 14a info');
    expect(RegExp(r'[\u3400-\u9fff]').hasMatch(chinese.localizedHint), isTrue);
    expect(RegExp(r'[\u3400-\u9fff]').hasMatch(english.localizedHint), isFalse);
  });

  test('analysis caches are locale-aware and format labels are localized', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(en.messageCommands(0), 'No commands');
    expect(en.messageCommands(1), '1 command');
    expect(en.messageCommands(2), '2 commands');
    expect(zh.messageCommands(2), '2 条');
    expect(madAidDescriptionsFor(en)[0x0038], 'Access control');
    expect(madAidDescriptionsFor(zh)[0x0038], '门禁控制');
    expect(DumpFormat.bin.localizedLabel(en), 'Binary dump (.bin)');
    expect(DumpFormat.bin.localizedLabel(zh), '二进制转储 (.bin)');
    final result = parseDumpBytes(
      // A valid blank 1K dump, not a hardware acquisition.
      Uint8List(1024),
    );
    final english = result.analysisFor(en);
    expect(identical(english, result.analysisFor(en)), isTrue);
    expect(identical(english, result.analysisFor(zh)), isFalse);
  });
}

Future<void> _render(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

AppState _appState() => _OfflineAppState(
      connectionState: connection.ConnectionState(
        controller: Pm3Controller(MockPm3Backend()),
        settingsStore: _Settings(),
      ),
    );

class _OfflineAppState extends AppState {
  _OfflineAppState({required super.connectionState});

  @override
  Future<void> scanForFiles() async {}
}

class _CatalogBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      SynchronousFuture(File(key).readAsStringSync());

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _Settings implements Pm3SettingsRepository {
  @override
  Future<Pm3ClientSettings?> load() async => null;
  @override
  Future<void> save(Pm3ClientSettings settings) async {}
}
