import 'dart:io';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pm3gui/l10n/app_locale_controller.dart';
import 'package:pm3gui/services/locale_settings_store.dart';
import '../support/localized_test_app.dart';

void main() {
  test('default follows the system and explicit selection survives restart',
      () async {
    final repository = MemoryLocaleSettings();
    final controller = AppLocaleController(repository: repository);
    await controller.initialize();
    expect(controller.locale, isNull);
    await controller.setLocale(const Locale('en'));
    expect(repository.language, 'en');
    final restored = AppLocaleController(repository: repository);
    await restored.initialize();
    expect(restored.locale, const Locale('en'));
    await restored.setLocale(null);
    expect(repository.language, isNull);
    controller.dispose();
    restored.dispose();
  });

  test('unsupported selection is rejected without changing the preference',
      () async {
    final controller =
        AppLocaleController(repository: MemoryLocaleSettings('zh'));
    await controller.initialize();
    await expectLater(
        controller.setLocale(const Locale('fr')), throwsArgumentError);
    expect(controller.locale, const Locale('zh'));
    controller.dispose();
  });

  test('read and write failures are visible rather than reported as saved',
      () async {
    final controller = AppLocaleController(repository: _FailingRepository());
    await controller.initialize();
    expect(controller.error, isA<FormatException>());
    await controller.setLocale(const Locale('en'));
    expect(controller.error, isA<FileSystemException>());
    expect(controller.isSaving, isFalse);
    controller.dispose();
  });

  test('rapid selections are serialized and flush persists the last selection',
      () async {
    final directory = await Directory.systemTemp.createTemp('pm3-locale-');
    try {
      final repository =
          LocaleSettingsStore(directoryProvider: () async => directory);
      final controller = AppLocaleController(repository: repository);
      await controller.initialize();
      final saves = [
        controller.setLocale(const Locale('en')),
        controller.setLocale(const Locale('zh')),
        controller.setLocale(null),
        controller.setLocale(const Locale('en')),
      ];
      await controller.flush();
      await Future.wait(saves);
      expect(await repository.load(), 'en');
      expect(
          directory
              .listSync()
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last),
          ['language.json']);
      expect(
          jsonDecode(await File(
                  '${directory.path}${Platform.pathSeparator}language.json')
              .readAsString()),
          {'language': 'en'});
      controller.dispose();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('invalid saved language is surfaced and can be replaced', () async {
    final controller =
        AppLocaleController(repository: MemoryLocaleSettings('unsupported'));
    await controller.initialize();
    expect(controller.error, isA<FormatException>());
    expect(controller.locale, isNull);
    await controller.setLocale(const Locale('zh'));
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('directory lookup failure is exposed without blocking initialization',
      () async {
    final failure =
        MissingPlatformDirectoryException('support directory unavailable');
    final controller = AppLocaleController(
      repository: LocaleSettingsStore(
        directoryProvider: () async => throw failure,
      ),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.flush();

    expect(controller.locale, isNull);
    expect(controller.error, isA<FileSystemException>());
    expect(controller.error.toString(), contains(failure.toString()));
    expect(controller.isSaving, isFalse);
  });

  test('directory lookup save failures do not poison later queued saves',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('pm3-locale-directory-');
    addTearDown(() => directory.delete(recursive: true));
    var unavailable = false;
    final store = LocaleSettingsStore(directoryProvider: () async {
      if (unavailable) {
        throw MissingPlatformDirectoryException(
            'support directory unavailable');
      }
      return directory;
    });
    final controller = AppLocaleController(repository: store);
    addTearDown(controller.dispose);
    await controller.initialize();
    unavailable = true;

    await Future.wait([
      controller.setLocale(const Locale('en')),
      controller.setLocale(const Locale('zh')),
    ]);
    await controller.flush();

    expect(controller.locale, const Locale('zh'));
    expect(controller.error, isA<FileSystemException>());
    expect(controller.isSaving, isFalse);

    unavailable = false;
    await controller.setLocale(const Locale('en'));
    await controller.flush();

    expect(controller.error, isNull);
    expect(controller.isSaving, isFalse);
    expect(await store.load(), 'en');
  });
}

class _FailingRepository implements LocaleSettingsRepository {
  @override
  Future<String?> load() async => throw const FormatException('invalid JSON');
  @override
  Future<void> save(String? languageCode) async =>
      throw const FileSystemException('permission denied');
}
