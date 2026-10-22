/// Key file parser and exporter.
///
/// PM3 key file formats:
///   .bin key file — raw binary: sectorCount × 12 bytes (6 KeyA + 6 KeyB)
///   .dic         — text dictionary: one hex key per line, # comments
///
/// This module can:
///   - Parse .bin key files and .dic key dictionaries
///   - Export keys from a MifareCard to all key formats
///   - Merge/compare key sets
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

// ---------------------------------------------------------------------------
//  Binary key file (.bin)  —  sectorCount × 12 bytes
// ---------------------------------------------------------------------------

/// Parse a binary key file. Returns keys indexed by sector.
List<SectorKey> parseKeyBinBytes(Uint8List data) {
  // Detect card type from key file size
  CardType? ct;
  for (final c in [cardMini, card1K, card2K, card4K]) {
    if (data.length == c.sectorCount * 12) {
      ct = c;
      break;
    }
  }
  if (ct == null) {
    throw FormatException(
      'Not a valid key file: ${data.length} bytes '
      '(expected ${cardMini.sectorCount * 12} / ${card1K.sectorCount * 12} / '
      '${card2K.sectorCount * 12} / ${card4K.sectorCount * 12})',
    );
  }

  // PM3 key file layout: [KeyA_s0..KeyA_sN][KeyB_s0..KeyB_sN]
  // First half: all Key A (sectorCount × 6 bytes)
  // Second half: all Key B (sectorCount × 6 bytes)
  final n = ct.sectorCount;
  return List.generate(n, (s) {
    return SectorKey(
      keyA: _bytesToHex(data, s * 6, 6),
      keyB: _bytesToHex(data, n * 6 + s * 6, 6),
    );
  });
}

/// Parse a binary key file from disk.
Future<List<SectorKey>> parseKeyBinFile(File file) async {
  final bytes = await file.readAsBytes();
  return parseKeyBinBytes(Uint8List.fromList(bytes));
}

/// Export keys to binary format: sectorCount × 12 bytes.
/// PM3 layout: [KeyA_s0..KeyA_sN][KeyB_s0..KeyB_sN]
Uint8List exportKeysToBin(List<SectorKey> keys) {
  final n = keys.length;
  final out = Uint8List(n * 12);
  for (var i = 0; i < n; i++) {
    final a = _hexToBytes(keys[i].keyA.padRight(12, '0'));
    final b = _hexToBytes(keys[i].keyB.padRight(12, '0'));
    out.setRange(i * 6, i * 6 + 6, a); // first half: all Key A
    out.setRange(n * 6 + i * 6, n * 6 + i * 6 + 6, b); // second half: all Key B
  }
  return out;
}

// ---------------------------------------------------------------------------
//  Text key dictionary (.dic)
// ---------------------------------------------------------------------------

/// Parse a .dic text key dictionary.
/// Returns a deduplicated list of 12-char hex key strings.
List<String> parseDicString(String text) {
  final keys = <String>{};
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final hex = trimmed.replaceAll(' ', '').toUpperCase();
    if (hex.length == 12 && RegExp(r'^[0-9A-F]{12}$').hasMatch(hex)) {
      keys.add(hex);
    }
  }
  return keys.toList();
}

/// Parse a .dic file from disk.
Future<List<String>> parseDicFile(File file) async {
  final text = await file.readAsString();
  return parseDicString(text);
}

/// Export a unique set of keys to .dic format string.
String exportToDic(List<SectorKey> keys, {String header = ''}) {
  // Collect unique keys
  final unique = <String>{};
  for (final k in keys) {
    if (k.keyA.isNotEmpty) unique.add(k.keyA.toUpperCase());
    if (k.keyB.isNotEmpty) unique.add(k.keyB.toUpperCase());
  }

  final buf = StringBuffer();
  buf.writeln('# PM3GUI Key Dictionary');
  if (header.isNotEmpty) buf.writeln('# $header');
  buf.writeln('#');
  for (final k in unique) {
    buf.writeln(k);
  }
  return buf.toString();
}

/// Export per-sector key table as human-readable text.
String exportKeysAsText(List<SectorKey> keys) {
  final buf = StringBuffer();
  buf.writeln('# PM3GUI — Sector Key Table');
  buf.writeln('# Sector | Key A        | Key B');
  buf.writeln('#--------+--------------+-------------');
  for (var i = 0; i < keys.length; i++) {
    buf.writeln(
      '${i.toString().padLeft(6)}   '
      '${keys[i].keyA.toUpperCase()}   '
      '${keys[i].keyB.toUpperCase()}',
    );
  }
  return buf.toString();
}

/// Read the indexed text format emitted by exportKeysAsText, without inventing missing sectors.
List<SectorKey> parseKeyText(String text, {AppLocalizations? localizations}) {
  final l10n = localizations ?? defaultLocalizations;
  final rows = <int, SectorKey>{};
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final match = RegExp(r'^(\d+)\s+([0-9a-fA-F]{12})\s+([0-9a-fA-F]{12})$')
        .firstMatch(line);
    if (match == null) throw FormatException(l10n.messageInvalidKeyTextFormat);
    final sector = int.parse(match.group(1)!);
    if (rows.containsKey(sector)) {
      throw FormatException(l10n.messageDuplicateSector((sector).toString()));
    }
    rows[sector] = SectorKey(
        keyA: match.group(2)!.toUpperCase(),
        keyB: match.group(3)!.toUpperCase());
  }
  if (![5, 16, 32, 40].contains(rows.length) ||
      List.generate(rows.length, (i) => i).any((i) => !rows.containsKey(i))) {
    throw FormatException(l10n.messageKeyTextIsMissingSectors);
  }
  return List.generate(rows.length, (i) => rows[i]!);
}

// ---------------------------------------------------------------------------
//  Utility — merge keys into a MifareCard
// ---------------------------------------------------------------------------

/// Apply a key list to a card, filling only blank/default keys.
void mergeKeysIntoCard(MifareCard card, List<SectorKey> newKeys,
    {bool overwrite = false}) {
  for (var i = 0; i < card.sectorKeys.length && i < newKeys.length; i++) {
    if (overwrite || _isDefaultKey(card.sectorKeys[i].keyA)) {
      card.sectorKeys[i].keyA = newKeys[i].keyA.toUpperCase();
    }
    if (overwrite || _isDefaultKey(card.sectorKeys[i].keyB)) {
      card.sectorKeys[i].keyB = newKeys[i].keyB.toUpperCase();
    }
  }
}

bool _isDefaultKey(String key) {
  return key.isEmpty ||
      key == 'FFFFFFFFFFFF' ||
      key == '000000000000' ||
      key.length != 12;
}

// ---------------------------------------------------------------------------
//  Internal helpers
// ---------------------------------------------------------------------------

String _bytesToHex(Uint8List data, int offset, int length) {
  final buf = StringBuffer();
  for (var i = 0; i < length && (offset + i) < data.length; i++) {
    buf.write(data[offset + i].toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  return buf.toString();
}

Uint8List _hexToBytes(String hex) {
  final h = hex.toUpperCase();
  final bytes = Uint8List(h.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
