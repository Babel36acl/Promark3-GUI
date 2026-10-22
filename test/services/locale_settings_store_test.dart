import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pm3gui/services/locale_settings_store.dart';

void main() {
  final failures = <Exception>[
    MissingPlatformDirectoryException(
      'support directory unavailable',
      details: 'native lookup detail',
    ),
    PlatformException(
      code: 'directory_unavailable',
      message: 'support directory unavailable',
      details: 'native lookup detail',
    ),
    MissingPluginException('path provider unavailable'),
  ];

  for (final failure in failures) {
    test('load normalizes ${failure.runtimeType} directory lookup failures',
        () async {
      final store = _failingStore(failure);

      await expectLater(store.load(), _storageFailure(failure));
    });

    test('save normalizes ${failure.runtimeType} directory lookup failures',
        () async {
      final store = _failingStore(failure);

      await expectLater(store.save('en'), _storageFailure(failure));
    });
  }

  test('directory lookup conversion preserves the original stack', () async {
    final failure = MissingPlatformDirectoryException('lookup failed');
    final originalStack =
        StackTrace.fromString('path_provider directory lookup');
    final store = LocaleSettingsStore(
      directoryProvider: () => Future<Directory>.error(failure, originalStack),
    );

    try {
      await store.load();
      fail('Expected a storage failure');
    } on FileSystemException catch (error, stack) {
      expect(error.message, contains(failure.toString()));
      expect(stack.toString(), originalStack.toString());
    }
  });

  for (final save in [false, true]) {
    final operation = save ? 'save' : 'load';
    test('$operation preserves an existing directory FileSystemException',
        () async {
      final failure = FileSystemException(
        'access denied',
        'application-support',
        const OSError('access denied', 5),
      );
      final store = _failingStore(failure);

      await expectLater(
        save ? store.save('en') : store.load(),
        throwsA(same(failure)),
      );
    });

    test('$operation does not mask unexpected directory provider errors',
        () async {
      final failure = StateError('unexpected provider bug');
      final store = _failingStore(failure);

      await expectLater(
        save ? store.save('en') : store.load(),
        throwsA(same(failure)),
      );
    });
  }
}

LocaleSettingsStore _failingStore(Object failure) => LocaleSettingsStore(
      directoryProvider: () async => throw failure,
    );

Matcher _storageFailure(Exception cause) => throwsA(
      isA<FileSystemException>().having(
        (error) => error.message,
        'directory lookup diagnostic',
        contains(cause.toString()),
      ),
    );
