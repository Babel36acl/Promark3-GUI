/// Dump format converter — convert between bin/eml/json/key formats.
///
/// Supports:
///   .bin (full dump) ↔ .eml ↔ .json ↔ .bin (key only)
///   .dic (key dictionary) ← any dump or key file
///   Key extraction from any dump format
///   Key injection into any dump format
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/parsers/dump_parser.dart';
import 'package:pm3gui/parsers/bin_parser.dart';
import 'package:pm3gui/parsers/eml_parser.dart';
import 'package:pm3gui/parsers/json_dump_parser.dart';
import 'package:pm3gui/parsers/key_parser.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

/// Supported file formats for conversion.
enum DumpFormat {
  bin('bin', true),
  eml('eml', true),
  json('json', true),
  keyBin('key.bin', false),
  dic('dic', false),
  keyTxt('keys.txt', false);

  final String ext;
  String get label => localizedLabel(defaultLocalizations);
  final bool isFullDump; // true = contains block data, false = keys only

  const DumpFormat(this.ext, this.isFullDump);

  String localizedLabel(AppLocalizations l10n) => switch (this) {
        bin => l10n.messageBinaryDumpBin,
        eml => l10n.messageTextDumpEml,
        json => 'PM3 JSON (.json)',
        keyBin => l10n.messageBinaryKeysKeyBin,
        dic => l10n.messageKeyDictionaryDic,
        keyTxt => l10n.messageKeyListKeysTxt,
      };
}

/// Result of a conversion operation.
class ConvertResult {
  final bool success;
  final String? error;

  /// Output file path (null if not written to disk).
  final String? outputPath;

  /// Key summary extracted during conversion.
  final String? keySummary;

  ConvertResult({
    required this.success,
    this.error,
    this.outputPath,
    this.keySummary,
  });
}

/// Convert a dump file from one format to another.
///
/// [inputPath] — path to source file
/// [outputPath] — where to write the converted output
/// [targetFormat] — desired output format
Future<ConvertResult> convertDumpFile({
  required String inputPath,
  required String outputPath,
  required DumpFormat targetFormat,
  AppLocalizations? localizations,
}) async {
  final l10n = localizations ?? defaultLocalizations;
  try {
    // ---- Parse input ----
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      return ConvertResult(
          success: false,
          error: l10n.messageFileNotFound((inputPath).toString()));
    }

    final ext = inputPath.split('.').last.toLowerCase();
    MifareCard? card;
    List<SectorKey>? keysOnly;

    // Check if input is a key-only binary file
    if (ext == 'bin' || ext == 'dump') {
      final bytes = await inputFile.readAsBytes();
      final data = Uint8List.fromList(bytes);
      // Detect key-only vs full dump
      if (_isKeyBinSize(data.length)) {
        keysOnly = parseKeyBinBytes(data);
      } else {
        final result = await parseDumpFile(inputPath);
        if (!result.isSuccess) {
          return ConvertResult(success: false, error: result.error);
        }
        card = result.card;
      }
    } else if (ext == 'dic' || ext == 'txt') {
      // Text key dictionary
      final text = await inputFile.readAsString();
      final dictKeys = parseDicString(text);
      // Build keys-only structure (all sectors same key list)
      keysOnly = _dictKeysToSectorKeys(dictKeys);
    } else {
      // EML / JSON / other — full dump parse
      final result = await parseDumpFile(inputPath);
      if (!result.isSuccess) {
        return ConvertResult(success: false, error: result.error);
      }
      card = result.card;
    }

    // ---- Generate output ----
    final outFile = File(outputPath);

    switch (targetFormat) {
      case DumpFormat.bin:
        if (card == null) {
          return ConvertResult(
              success: false, error: l10n.messageAKeyFileCannotBeConvertedTo);
        }
        await outFile.writeAsBytes(exportToBin(card));

      case DumpFormat.eml:
        if (card == null) {
          return ConvertResult(
              success: false, error: l10n.messageAKeyFileCannotBeConvertedTo2);
        }
        await outFile.writeAsString(exportToEml(card));

      case DumpFormat.json:
        if (card == null) {
          return ConvertResult(
              success: false, error: l10n.messageAKeyFileCannotBeConvertedTo3);
        }
        await outFile.writeAsString(exportToJson(card));

      case DumpFormat.keyBin:
        final keys = card?.sectorKeys ?? keysOnly;
        if (keys == null || keys.isEmpty) {
          return ConvertResult(success: false, error: l10n.messageNoKeyData);
        }
        await outFile.writeAsBytes(exportKeysToBin(keys));

      case DumpFormat.dic:
        final keys = card?.sectorKeys ?? keysOnly;
        if (keys == null || keys.isEmpty) {
          return ConvertResult(success: false, error: l10n.messageNoKeyData);
        }
        await outFile.writeAsString(exportToDic(keys));

      case DumpFormat.keyTxt:
        final keys = card?.sectorKeys ?? keysOnly;
        if (keys == null || keys.isEmpty) {
          return ConvertResult(success: false, error: l10n.messageNoKeyData);
        }
        await outFile.writeAsString(exportKeysAsText(keys));
    }

    // Build key summary
    final keys = card?.sectorKeys ?? keysOnly;
    final summary = keys != null ? _buildKeySummary(keys, l10n) : null;

    return ConvertResult(
      success: true,
      outputPath: outputPath,
      keySummary: summary,
    );
  } catch (e) {
    return ConvertResult(
        success: false, error: l10n.messageConversionFailed((e).toString()));
  }
}

/// Extract keys from any supported dump file.
///
/// Returns (sectorKeys, keySummaryText) or throws on error.
Future<(List<SectorKey>, String)> extractKeysFromFile(String path,
    {AppLocalizations? localizations}) async {
  final l10n = localizations ?? defaultLocalizations;
  final file = File(path);
  if (!await file.exists()) {
    throw Exception(l10n.messageFileNotFound((path).toString()));
  }

  final ext = path.split('.').last.toLowerCase();

  // Try key-only binary first
  if (ext == 'bin' || ext == 'dump') {
    final bytes = await file.readAsBytes();
    final data = Uint8List.fromList(bytes);
    if (_isKeyBinSize(data.length)) {
      final keys = parseKeyBinBytes(data);
      return (keys, _buildKeySummary(keys, l10n));
    }
  }

  // Try text dictionary
  if (ext == 'dic' || ext == 'txt') {
    final text = await file.readAsString();
    final dictKeys = parseDicString(text);
    final keys = _dictKeysToSectorKeys(dictKeys);
    return (keys, l10n.messageUniqueKeys((dictKeys.length).toString()));
  }

  // Full dump — parse and extract
  final result = await parseDumpFile(path);
  if (!result.isSuccess) throw Exception(result.error);
  final keys = result.card.sectorKeys;
  return (keys, _buildKeySummary(keys, l10n));
}

/// Write keys to a file in the requested format.
Future<void> saveKeysToFile(List<SectorKey> keys, String path, DumpFormat fmt,
    {AppLocalizations? localizations}) async {
  final l10n = localizations ?? defaultLocalizations;
  switch (fmt) {
    case DumpFormat.keyBin:
      await File(path).writeAsBytes(exportKeysToBin(keys));
    case DumpFormat.dic:
      await File(path).writeAsString(exportToDic(keys));
    case DumpFormat.keyTxt:
      await File(path).writeAsString(exportKeysAsText(keys));
    default:
      throw ArgumentError(
          l10n.messageUnsupportedKeyExportFormat(fmt.localizedLabel(l10n)));
  }
}

// ---------------------------------------------------------------------------
//  Allowed conversion matrix
// ---------------------------------------------------------------------------

/// Return a list of formats the source format can convert to.
List<DumpFormat> allowedTargets(String sourceExt) {
  final e = sourceExt.toLowerCase();
  // Full dump formats can convert to anything
  if (['eml', 'json'].contains(e)) {
    return DumpFormat.values.toList();
  }
  // Bin could be full dump or keys — allow all targets
  if (['bin', 'dump'].contains(e)) {
    return DumpFormat.values.toList();
  }
  // Key-only formats can only produce other key formats
  if (['dic', 'txt'].contains(e)) {
    return [DumpFormat.keyBin, DumpFormat.dic, DumpFormat.keyTxt];
  }
  return DumpFormat.values.toList();
}

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

bool _isKeyBinSize(int bytes) {
  for (final c in [cardMini, card1K, card2K, card4K]) {
    if (bytes == c.sectorCount * 12) return true;
  }
  return false;
}

List<SectorKey> _dictKeysToSectorKeys(List<String> dictKeys) {
  // Default: fill 16 sectors (1K) with first available key
  final kA = dictKeys.isNotEmpty ? dictKeys[0] : 'FFFFFFFFFFFF';
  final kB = dictKeys.length > 1 ? dictKeys[1] : kA;
  return List.generate(16, (_) => SectorKey(keyA: kA, keyB: kB));
}

String _buildKeySummary(List<SectorKey> keys, AppLocalizations l10n) {
  final uniqueA = keys.map((k) => k.keyA.toUpperCase()).toSet();
  final uniqueB = keys.map((k) => k.keyB.toUpperCase()).toSet();
  final allKeys = {...uniqueA, ...uniqueB};
  return l10n.messageSectorsUniqueKeyAUniqueKeyB(
      (keys.length).toString(),
      (uniqueA.length).toString(),
      (uniqueB.length).toString(),
      (allKeys.length).toString());
}
