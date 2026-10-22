import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/l10n/app_localizations.dart';
import 'package:pm3gui/models/command_card.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/parsers/key_parser.dart';

void main() {
  test(
      'key rows use sector numbers, reject failed keys and survive unrelated commands',
      () {
    final card = CommandCard()..beginCommand('hf mf chk --1k');
    card.consume('[+] 003 | 015 | A0A1A2A3A4A5 | 1 | 000000000000 | 0');
    card.consume('[+] 001 | 007 | FFFFFFFFFFFF | D | ------------ | -');
    card.consume(
        '[+] Target sector 2 key type B -- found valid key [ B0B1B2B3B4B5 ]');
    expect(card.keysA, {3: 'A0A1A2A3A4A5', 1: 'FFFFFFFFFFFF'});
    expect(card.keysB, {2: 'B0B1B2B3B4B5'});
    card.beginCommand('hf iclass info');
    card.consume('[+] 000 | 003 | AAAAAAAAAAAA | 1 | BBBBBBBBBBBB | 1');
    expect(card.keysA.containsKey(0), isFalse);
    expect(card.exportBin, throwsFormatException);
  });

  test('target block and hardnested result use 4K sector mapping', () {
    final card = CommandCard()..beginCommand('hf mf fchk --4k');
    card.consume(
        '[+] Target block 144 key type A -- found valid key [ 0123456789AB ]');
    expect(card.keysA[33], '0123456789AB');
    card.beginCommand(
        'hf mf hardnested --blk 0 -a -k FFFFFFFFFFFF --tblk 160 --tb');
    card.consume(
        '[=] 3 | 100 | Brute force completed. Key found: AABBCCDDEEFF | 0 | 0s');
    expect(card.keysB[34], 'AABBCCDDEEFF');
    card.beginCommand('hf mf hardnested -t 10 --tblk 176 --ta');
    card.consume('Brute force completed. Key found: FFFFFFFFFFFF');
    expect(card.keysA.containsKey(35), isFalse);
  });

  test('reads retain block addresses and mask unreadable trailer keys', () {
    final card = CommandCard()
      ..beginCommand('hf mf rdsc --sec 1 -a -k FFFFFFFFFFFF');
    card.consume(
        '[=] 1 | 4 | 00 11 22 33 44 55 66 77 88 99 AA BB CC DD EE FF | ascii');
    card.consume(
        '[=]   | 7 | 00 00 00 00 00 00 FF 07 80 69 FF FF FF FF FF FF | ascii');
    expect(card.blocks[4], '00112233445566778899AABBCCDDEEFF');
    expect(card.blocks[7], '${'?' * 12}FF078069${'?' * 12}');
    expect(card.keysA, isEmpty);
    card.editKey(1, true, 'A0 A1 A2 A3 A4 A5');
    card.keysToTrailers();
    expect(card.blocks[7], 'A0A1A2A3A4A5FF078069${'?' * 12}');
  });

  test('draft round trip preserves unknowns and invalid import is atomic', () {
    final card = CommandCard()
      ..editBlock(2, '?' * 32)
      ..editKey(3, false, 'ABCDEF012345');
    final saved = card.exportDraft();
    final restored = CommandCard()..importDraft(saved);
    expect(restored.exportDraft(), saved);
    expect(() => restored.importDraft(saved.replaceFirst('ABCDEF012345', 'ZZ')),
        throwsFormatException);
    expect(restored.exportDraft(), saved);
    expect(restored.exportKeyBin, throwsFormatException);
    expect(restored.exportDictionary(), 'ABCDEF012345\n');
  });

  for (final field in ['blocks', 'keysA', 'keysB']) {
    test('English draft import localizes invalid $field and remains atomic',
        () {
      final english = lookupAppLocalizations(const Locale('en'));
      final card = _populatedCard(english);
      final saved = card.exportDraft();
      final draft = jsonEncode({
        'format': 'pm3gui-command-card-v1',
        'blocksCount': card1K.blockCount,
        'uid': '55667788',
        'blocks': {'0': field == 'blocks' ? 'ZZ' : 'CD' * 16},
        'keysA': {'0': field == 'keysA' ? 'ZZ' : 'C0C1C2C3C4C5'},
        'keysB': {'0': field == 'keysB' ? 'ZZ' : 'D0D1D2D3D4D5'},
      });
      final message = english.messageEnterHexDigitsUseForUnknownDigits(
          field == 'blocks' ? '32' : '12');

      expect(
        () => card.importDraft(draft),
        throwsA(isA<FormatException>()
            .having((error) => error.message, 'English message', message)),
      );
      expect(card.exportDraft(), saved);
      expect(card.l10n, same(english));
    });

    test('English card import localizes invalid $field and remains atomic', () {
      final english = lookupAppLocalizations(const Locale('en'));
      final card = _populatedCard(english);
      final saved = card.exportDraft();
      final imported = MifareCard(uid: '55667788');
      switch (field) {
        case 'blocks':
          imported.blocks[0] = 'ZZ';
        case 'keysA':
          imported.sectorKeys[0].keyA = 'ZZ';
        case 'keysB':
          imported.sectorKeys[0].keyB = 'ZZ';
      }
      final message = english.messageEnterHexDigitsUseForUnknownDigits(
          field == 'blocks' ? '32' : '12');

      expect(
        () => card.importCard(imported),
        throwsA(isA<FormatException>()
            .having((error) => error.message, 'English message', message)),
      );
      expect(card.exportDraft(), saved);
      expect(card.l10n, same(english));
    });
  }

  test('complete export has correct capacity and RRG key ordering', () {
    final card = CommandCard()..clear(cardType: cardMini);
    for (var b = 0; b < 20; b++) {
      card.editBlock(b, 'AB' * 16);
    }
    for (var s = 0; s < 5; s++) {
      card.editKey(s, true, 'A0A1A2A3A4A5');
      card.editKey(s, false, 'B0B1B2B3B4B5');
    }
    expect(card.exportBin(), hasLength(320));
    final keys = parseKeyBinBytes(card.exportKeyBin());
    final textKeys = parseKeyText(exportKeysAsText(keys));
    expect(textKeys[4].keyB, 'B0B1B2B3B4B5');
    expect(() => parseKeyText('0 FFFFFFFFFFFF FFFFFFFFFFFF'),
        throwsFormatException);
    expect(keys[4].keyA, 'A0A1A2A3A4A5');
    expect(keys[0].keyB, 'B0B1B2B3B4B5');
    expect(MifareCard(cardType: card4K).blocks, hasLength(256));
  });

  test('new UID clears previous card data', () {
    final card = CommandCard()..beginCommand('hf 14a reader');
    card.consume('[+] UID: 11 22 33 44');
    card.editKey(0, true, 'FFFFFFFFFFFF');
    card.consume('[+] UID: 55 66 77 88');
    expect(card.uid, '55667788');
    expect(card.keysA, isEmpty);
  });
}

CommandCard _populatedCard(AppLocalizations localizations) => CommandCard()
  ..updateLocalizations(localizations)
  ..clear(cardType: cardMini)
  ..uid = '11223344'
  ..editBlock(0, 'AB' * 16)
  ..editKey(0, true, 'A0A1A2A3A4A5')
  ..editKey(0, false, 'B0B1B2B3B4B5');
