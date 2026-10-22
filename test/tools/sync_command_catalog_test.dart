import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../support/dart_executable.dart';

void main() {
  final projectDirectory = Directory.current.absolute;
  final tool = File(
    '${projectDirectory.path}${Platform.pathSeparator}tools'
    '${Platform.pathSeparator}sync_command_catalog.dart',
  );

  Future<ProcessResult> runTool(List<String> arguments) => Process.run(
        dartExecutable,
        ['run', tool.path, ...arguments],
        workingDirectory: projectDirectory.path,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  test('standalone Dart reaches the catalog tool usage handler', () async {
    final result = await runTool([]);

    expect(result.exitCode, 2, reason: result.stderr.toString());
    expect(result.stderr,
        contains('Usage: dart run tools/sync_command_catalog.dart'));
    expect(result.stderr, isNot(contains("Dart library 'dart:ui'")));
  });

  test('standalone Dart constructs the process and reports a missing client',
      () async {
    final directory = await Directory.systemTemp.createTemp('pm3-standalone-');
    try {
      final missingClient = File(
        '${directory.path}${Platform.pathSeparator}missing-proxmark3',
      );
      final snapshot = File(
        '${projectDirectory.path}${Platform.pathSeparator}docs'
        '${Platform.pathSeparator}pm3_commands_client.json',
      );
      final before = await snapshot.readAsBytes();

      final result = await runTool([missingClient.path, 'test-port']);

      expect(result.exitCode, 1, reason: result.stderr.toString());
      expect(result.stderr, contains('Help group "connection":'));
      expect(result.stderr, contains(missingClient.path));
      expect(result.stderr, isNot(contains("Dart library 'dart:ui'")));
      expect(await snapshot.readAsBytes(), before);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
