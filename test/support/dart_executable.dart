import 'dart:io';

String get dartExecutable {
  final executable = File(Platform.resolvedExecutable);
  final name = executable.uri.pathSegments.last.toLowerCase();
  if (name == 'dart' || name == 'dart.exe') return executable.path;

  final separator = Platform.pathSeparator;
  final dartName = Platform.isWindows ? 'dart.exe' : 'dart';
  var directory = executable.parent;
  while (directory.parent.path != directory.path) {
    final candidate = File(
      '${directory.path}${separator}dart-sdk${separator}bin$separator$dartName',
    );
    if (candidate.existsSync()) return candidate.path;
    directory = directory.parent;
  }
  throw StateError('Unable to locate the Dart SDK beside $executable');
}
