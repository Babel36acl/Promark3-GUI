import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class TestFileDialogs {
  TestFileDialogs() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      final selectedOpenPath = openPath;
      return switch (call.method) {
        'getSavePath' => savePath,
        'openFile' => selectedOpenPath == null ? null : [selectedOpenPath],
        _ => throw PlatformException(
            code: 'unexpected-file-dialog',
            message: 'Unexpected file dialog method: ${call.method}',
          ),
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
  }

  static const _channel = MethodChannel('plugins.flutter.io/file_selector');
  final calls = <MethodCall>[];
  String? savePath;
  String? openPath;
}

Future<void> pumpFileOperation(
    WidgetTester tester, bool Function() completed) async {
  for (var attempt = 0; attempt < 100 && !completed(); attempt++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(completed(), isTrue,
      reason: 'The file operation did not reach the expected UI state.');
}
