/// Unified dump file parser.
///
/// Detects format by file extension and delegates to specific parsers.
/// Supports .eml, .bin/.dump, .json formats matching PM3 client output.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/models/dump_analysis.dart';
import 'package:pm3gui/parsers/eml_parser.dart';
import 'package:pm3gui/parsers/bin_parser.dart';
import 'package:pm3gui/parsers/json_dump_parser.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

/// Result of parsing a dump file.
class DumpResult {
  final MifareCard card;
  final String format; // 'eml', 'bin', 'json'
  final String? error;
  DumpAnalysis? _analysis;
  String? _analysisLocale;

  DumpResult({required this.card, required this.format, this.error});
  bool get isSuccess => error == null;

  /// 获取或生成深度分析结果 (懒加载)
  DumpAnalysis get analysis => analysisFor(defaultLocalizations);

  DumpAnalysis analysisFor(AppLocalizations localizations) {
    if (_analysisLocale != localizations.localeName) {
      _analysis = null;
      _analysisLocale = localizations.localeName;
    }
    _analysis ??= DumpAnalyzer.analyze(card, localizations: localizations);
    return _analysis!;
  }
}

/// Parse a dump file from path, auto-detecting format.
Future<DumpResult> parseDumpFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    return DumpResult(
      card: MifareCard(),
      format: 'unknown',
      error: 'File not found: $filePath',
    );
  }

  final ext = filePath.split('.').last.toLowerCase();

  try {
    switch (ext) {
      case 'eml':
        return DumpResult(
          card: await parseEmlFile(file),
          format: 'eml',
        );
      case 'bin':
      case 'dump':
        return DumpResult(
          card: await parseBinFile(file),
          format: 'bin',
        );
      case 'json':
        return DumpResult(
          card: await parseJsonDumpFile(file),
          format: 'json',
        );
      default:
        // Try to auto-detect by content
        return await _autoDetectAndParse(file);
    }
  } catch (e) {
    return DumpResult(
      card: MifareCard(),
      format: ext,
      error: 'Parse error: $e',
    );
  }
}

/// Parse from raw bytes with explicit format hint.
DumpResult parseDumpBytes(Uint8List data, {String format = 'bin'}) {
  try {
    switch (format) {
      case 'eml':
        return DumpResult(
          card: parseEmlString(String.fromCharCodes(data)),
          format: 'eml',
        );
      case 'bin':
      case 'dump':
        return DumpResult(
          card: parseBinBytes(data),
          format: 'bin',
        );
      case 'json':
        return DumpResult(
          card: parseJsonDumpString(String.fromCharCodes(data)),
          format: 'json',
        );
      default:
        return DumpResult(
          card: parseBinBytes(data),
          format: 'bin',
        );
    }
  } catch (e) {
    return DumpResult(
      card: MifareCard(),
      format: format,
      error: 'Parse error: $e',
    );
  }
}

/// Auto-detect file format by inspecting content.
Future<DumpResult> _autoDetectAndParse(File file) async {
  final bytes = await file.readAsBytes();

  // Check if it's valid JSON
  final text = String.fromCharCodes(bytes);
  if (text.trimLeft().startsWith('{')) {
    try {
      return DumpResult(
        card: parseJsonDumpString(text),
        format: 'json',
      );
    } catch (_) {}
  }

  // Check if it looks like EML (ascii hex lines)
  if (_looksLikeEml(text)) {
    try {
      return DumpResult(
        card: parseEmlString(text),
        format: 'eml',
      );
    } catch (_) {}
  }

  // Fall back to binary
  try {
    return DumpResult(
      card: parseBinBytes(Uint8List.fromList(bytes)),
      format: 'bin',
    );
  } catch (e) {
    return DumpResult(
      card: MifareCard(),
      format: 'unknown',
      error: 'Could not detect file format: $e',
    );
  }
}

bool _looksLikeEml(String text) {
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return false;
  // EML lines are 32 hex chars (no spaces) or 47 chars (with spaces)
  final first = lines.first.trim();
  return RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(first) ||
      RegExp(r'^([0-9a-fA-F]{2}\s){15}[0-9a-fA-F]{2}$').hasMatch(first);
}
