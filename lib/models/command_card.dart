import 'dart:convert';
import 'dart:typed_data';

import 'mifare_card.dart';
import '../parsers/output_parser.dart';
import '../parsers/key_parser.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

/// 命令采集的未完成卡片。缺项保持未知，不能当作全零块或默认密钥。
/// 文件转储仍由 MifareCard 表示；只有完整草稿才能导出为转储。
class CommandCard with LocalizedMessages {
  CardType type = card1K;
  String uid = '';
  final Map<int, String> blocks = {};
  final Map<int, String> keysA = {};
  final Map<int, String> keysB = {};
  String _command = '';

  void clear({CardType? cardType}) {
    type = cardType ?? type;
    uid = '';
    blocks.clear();
    keysA.clear();
    keysB.clear();
    _command = '';
  }

  void beginCommand(String command) {
    _command = command.trim().toLowerCase();
    if (blocks.isEmpty &&
        keysA.isEmpty &&
        keysB.isEmpty &&
        _command.startsWith('hf mf ')) {
      final size =
          RegExp(r'--(mini|1k|2k|4k)\b').firstMatch(_command)?.group(1);
      type = switch (size) {
        'mini' => cardMini,
        '1k' => card1K,
        '2k' => card2K,
        '4k' => card4K,
        _ => type
      };
    }
  }

  int sectorForBlock(int block) =>
      block < 128 ? block ~/ 4 : 32 + (block - 128) ~/ 16;

  void consume(String output) {
    final parts = _command.split(RegExp(r'\s+'));
    if (parts.length < 3 || parts[0] != 'hf') return;
    final line =
        stripAnsi(output).replaceAll(RegExp(r'^\[[^\]]*\]\s*'), '').trim();
    if (parts[1] == '14a' || parts[1] == 'mf') {
      final foundUid = extractUid(line);
      if (foundUid != null && [8, 14, 20].contains(foundUid.length)) {
        if (uid.isNotEmpty && uid != foundUid) {
          final active = _command;
          clear();
          _command = active;
        }
        uid = foundUid;
      }
    }
    if (parts[1] != 'mf' || parts.contains('-h') || parts.contains('--help')) {
      return;
    }
    const keyCommands = {
      'chk',
      'fchk',
      'nested',
      'staticnested',
      'hardnested',
      'autopwn',
      'darkside'
    };
    const readCommands = {
      'rdbl',
      'rdsc',
      'cgetblk',
      'cgetsc',
      'egetblk',
      'eview',
      'view'
    };
    if (keyCommands.contains(parts[2])) {
      for (final key in extractKeys(line)) {
        if (key.sector < 0 || key.sector >= type.sectorCount) continue;
        if (key.keyAFound) keysA[key.sector] = key.keyA;
        if (key.keyBFound) keysB[key.sector] = key.keyB;
      }
      final target = RegExp(
              r'Target block\s+(\d+)\s+key type\s+([AB])\s+--\s+found valid key\s+\[\s*([0-9A-F]{12})\s*\]',
              caseSensitive: false)
          .firstMatch(line);
      if (target != null) {
        final sector = sectorForBlock(int.parse(target.group(1)!));
        if (sector < type.sectorCount) {
          (target.group(2)!.toUpperCase() == 'A' ? keysA : keysB)[sector] =
              target.group(3)!.toUpperCase();
        }
      }
      if (parts[2] == 'hardnested' &&
          !parts.contains('--test') &&
          !parts.contains('-t') &&
          !parts.contains('-r')) {
        final found = RegExp(
                r'Brute force completed\. Key found:\s*([0-9A-F]{12})\b',
                caseSensitive: false)
            .firstMatch(line);
        final targetBlock = RegExp(r'--tblk\s+(\d+)\b').firstMatch(_command);
        if (found != null &&
            targetBlock != null &&
            (parts.contains('--ta') || parts.contains('--tb'))) {
          final sector = sectorForBlock(int.parse(targetBlock.group(1)!));
          if (sector < type.sectorCount) {
            (parts.contains('--ta') ? keysA : keysB)[sector] =
                found.group(1)!.toUpperCase();
          }
        }
      }
    }
    if (!readCommands.contains(parts[2])) return;
    // RRG: [sec |] blk | sixteen bytes | ascii. Never infer a block from row order.
    final match = RegExp(
            r'^(?:\d*\s*\|\s*)?(\d{1,3})\s*\|\s*((?:[0-9a-fA-F]{2}[ \t]+){15}[0-9a-fA-F]{2})(?:\s*\||\s*$)')
        .firstMatch(line);
    if (match == null) return;
    final block = int.parse(match.group(1)!);
    if (block >= type.blockCount) return;
    var data = match.group(2)!.replaceAll(RegExp(r'\s'), '').toUpperCase();
    final sector = sectorForBlock(block);
    if (block == type.trailerBlock(sector) &&
        ['rdbl', 'rdsc'].contains(parts[2])) {
      // Authentication reads mask Key A, and Key B depends on access conditions.
      // Do not promote masked zero bytes into recovered keys.
      data =
          '${keysA[sector] ?? '?' * 12}${data.substring(12, 20)}${keysB[sector] ?? '?' * 12}';
    }
    blocks[block] = data;
  }

  String normalize(String value, int length) {
    final normalized = value.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (normalized.isNotEmpty &&
        (normalized.length != length ||
            !RegExp(r'^[0-9A-F?]+$').hasMatch(normalized))) {
      throw FormatException(
          l10n.messageEnterHexDigitsUseForUnknownDigits((length).toString()));
    }
    return normalized;
  }

  void editBlock(int block, String value) {
    if (block < 0 || block >= type.blockCount) {
      throw FormatException(l10n.messageBlockNumberExceedsTheCardCapacity);
    }
    final data = normalize(value, 32);
    if (data.isEmpty) {
      blocks.remove(block);
    } else {
      blocks[block] = data;
    }
  }

  void editKey(int sector, bool a, String value) {
    if (sector < 0 || sector >= type.sectorCount) {
      throw FormatException(l10n.messageSectorNumberExceedsTheCardCapacity);
    }
    final key = normalize(value, 12);
    final target = a ? keysA : keysB;
    if (key.isEmpty) {
      target.remove(sector);
    } else {
      target[sector] = key;
    }
  }

  void keysToTrailers() {
    for (var s = 0; s < type.sectorCount; s++) {
      if (!keysA.containsKey(s) && !keysB.containsKey(s)) continue;
      final b = type.trailerBlock(s);
      final previous = blocks[b] ?? '?' * 32;
      blocks[b] =
          '${keysA[s] ?? previous.substring(0, 12)}${previous.substring(12, 20)}${keysB[s] ?? previous.substring(20)}';
    }
  }

  void trailersToKeys() {
    for (var s = 0; s < type.sectorCount; s++) {
      final data = blocks[type.trailerBlock(s)];
      if (data == null) continue;
      if (!data.substring(0, 12).contains('?')) {
        keysA[s] = data.substring(0, 12);
      }
      if (!data.substring(20).contains('?')) keysB[s] = data.substring(20);
    }
  }

  String exportDraft() => const JsonEncoder.withIndent('  ').convert({
        'format': 'pm3gui-command-card-v1',
        'blocksCount': type.blockCount,
        'uid': uid,
        'blocks': blocks.map((k, v) => MapEntry('$k', v)),
        'keysA': keysA.map((k, v) => MapEntry('$k', v)),
        'keysB': keysB.map((k, v) => MapEntry('$k', v)),
      });

  void importDraft(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (json['format'] != 'pm3gui-command-card-v1') {
      throw FormatException(l10n.messageThisIsNotACommandDataDraft);
    }
    final cardType = CardType.fromBlockCount(json['blocksCount'] as int);
    if (cardType == null) {
      throw FormatException(l10n.messageUnsupportedCardCapacity);
    }
    final parsed = CommandCard()
      ..updateLocalizations(l10n)
      ..clear(cardType: cardType);
    parsed.uid = json['uid'] as String;
    if (parsed.uid.isNotEmpty &&
        !RegExp(r'^(?:[0-9A-F]{8}|[0-9A-F]{14}|[0-9A-F]{20})$')
            .hasMatch(parsed.uid)) {
      throw FormatException(l10n.messageInvalidUidFormat);
    }
    for (final item in (json['blocks'] as Map).entries) {
      parsed.editBlock(int.parse(item.key), item.value as String);
    }
    for (final item in (json['keysA'] as Map).entries) {
      parsed.editKey(int.parse(item.key), true, item.value as String);
    }
    for (final item in (json['keysB'] as Map).entries) {
      parsed.editKey(int.parse(item.key), false, item.value as String);
    }
    clear(cardType: cardType);
    uid = parsed.uid;
    blocks.addAll(parsed.blocks);
    keysA.addAll(parsed.keysA);
    keysB.addAll(parsed.keysB);
  }

  String exportEml() {
    for (var b = 0; b < type.blockCount; b++) {
      if (!RegExp(r'^[0-9A-F]{32}$').hasMatch(blocks[b] ?? '')) {
        throw FormatException(
            l10n.messageBlockIsIncompleteSaveADraftOr((b).toString()));
      }
    }
    return '${List.generate(type.blockCount, (b) => blocks[b]).join('\n')}\n';
  }

  Uint8List exportBin() {
    final hex = exportEml().replaceAll('\n', '');
    return Uint8List.fromList(List.generate(hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  void importCard(MifareCard card) {
    final parsed = CommandCard()
      ..updateLocalizations(l10n)
      ..clear(cardType: card.cardType);
    for (var b = 0; b < card.blocks.length; b++) {
      parsed.editBlock(b, card.blocks[b]);
    }
    for (var s = 0; s < card.sectorKeys.length; s++) {
      parsed.editKey(s, true, card.sectorKeys[s].keyA);
      parsed.editKey(s, false, card.sectorKeys[s].keyB);
    }
    clear(cardType: card.cardType);
    uid = card.uid;
    blocks.addAll(parsed.blocks);
    keysA.addAll(parsed.keysA);
    keysB.addAll(parsed.keysB);
  }

  Uint8List exportKeyBin() {
    final keys = <SectorKey>[];
    for (var s = 0; s < type.sectorCount; s++) {
      if (!RegExp(r'^[0-9A-F]{12}$').hasMatch(keysA[s] ?? '') ||
          !RegExp(r'^[0-9A-F]{12}$').hasMatch(keysB[s] ?? '')) {
        throw FormatException(l10n
            .messageSectorHasIncompleteKeysExportADictionary((s).toString()));
      }
      keys.add(SectorKey(keyA: keysA[s]!, keyB: keysB[s]!));
    }
    return exportKeysToBin(keys);
  }

  String exportDictionary() {
    final keys = {...keysA.values, ...keysB.values}
        .where((k) => RegExp(r'^[0-9A-F]{12}$').hasMatch(k));
    if (keys.isEmpty) {
      throw FormatException(l10n.messageThereAreNoCompleteKeysToExport);
    }
    return '${keys.join('\n')}\n';
  }
}
