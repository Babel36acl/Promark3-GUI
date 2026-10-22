import 'dart:convert';
import 'dart:io';

/// Run from the repository root; no packages or Flutter engine are required.
void main() {
  final directory = Directory('lib${Platform.pathSeparator}l10n');
  final template =
      _read(File('${directory.path}${Platform.pathSeparator}app_en.arb'));
  final keys = template.keys.where((key) => !key.startsWith('@')).toSet();
  final failures = <String>[];
  for (final file in directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.arb'))) {
    final messages = _read(file);
    final actual = messages.keys.where((key) => !key.startsWith('@')).toSet();
    final missing = keys.difference(actual);
    final extra = actual.difference(keys);
    if (missing.isNotEmpty) {
      failures.add('${file.path}: missing ${missing.join(', ')}');
    }
    if (extra.isNotEmpty) {
      failures.add('${file.path}: extra ${extra.join(', ')}');
    }
    for (final key in actual) {
      final value = messages[key];
      if (value is! String || value.trim().isEmpty) {
        failures.add('${file.path}: $key must be a nonempty string');
      }
    }
  }
  for (final key in keys) {
    if (!template.containsKey('@$key')) {
      failures.add('app_en.arb: $key needs translator metadata');
    }
    if (RegExp(r'[\u3400-\u9fff]').hasMatch(template[key] as String)) {
      failures.add('app_en.arb: $key contains untranslated Chinese');
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln(
        'Localization resources complete: ${keys.length} messages per language.');
  }
}

Map<String, dynamic> _read(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
