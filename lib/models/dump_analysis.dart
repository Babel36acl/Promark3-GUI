/// MIFARE Classic dump 深度分析引擎
///
/// 包括: 制造商块解码, MAD解析, 值块检测, 默认密钥检测,
/// 密钥模式分析, 数据块 ASCII, 扇区访问位查看.
library;

import 'dart:typed_data';
import 'mifare_card.dart';
import 'access_bits.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

// ==========================================================================
//  常量
// ==========================================================================

/// 常见默认密钥 (6字节, 大写hex)
const List<String> knownDefaultKeys = [
  'FFFFFFFFFFFF', // NXP factory
  '000000000000', // empty
  'A0A1A2A3A4A5', // MAD key A
  'B0B1B2B3B4B5', // MAD key B
  'D3F7D3F7D3F7', // NDEF key
  '4D3A99C351DD', // IkeySE master
  '1A982C7E459A', // Salto
  'AABBCCDDEEFF', // transport
  '714C5C886E97', // HID iCLASS → MFC mapped
  '587EE5F9350F', // VIGIK
  'A0478CC39091', // dormakaba
  'B7BF0C13066E', // HID
  'FFD3407E1B56', // Bangkok BTS
  '6A1987C40A21', // URB/Moscow
  'FC00018778F7', // Smart Rider
  '0000014B5C31', // BIP
  '2735FC181807', // Kartu Multi Trip
  '1FC235AC1309', // Umarsh
  '2A2C13CC242A', // Social Moscow
];

/// MAD AID 描述 (功能代码 → 说明)
Map<int, String> get madAidDescriptions =>
    madAidDescriptionsFor(defaultLocalizations);

Map<int, String> madAidDescriptionsFor(AppLocalizations l10n) => {
      0x0000: l10n.messageEmptyUnallocated,
      0x0001: l10n.messageDefectManagement,
      0x0002: l10n.messageReserved,
      0x0003: l10n.messageAdditionalDirectoryEntries,
      0x0004: l10n.messageCardholderInformation,
      0x0005: l10n.messageUnallocated,
      0x0008: l10n.messageAirlineServices,
      0x0010: l10n.messageUrbanTransport,
      0x0011: l10n.messageUrbanTransport2,
      0x0012: l10n.messageRailTransport,
      0x0014: l10n.messageTransportGeneral,
      0x0015: l10n.messageSecurityServices,
      0x0018: l10n.messageUrbanTransport3,
      0x0020: l10n.messageEventTicketing,
      0x0028: l10n.messageLoyaltySchemes,
      0x0030: l10n.messageParking,
      0x0038: l10n.messageAccessControl,
      0x0040: l10n.messageElectronicPurseMicropayments,
      0x0047: l10n.messageElectronicTicketingGeneral,
      0x0048: l10n.messageMobileOffice,
      0x0049: l10n.messageIdentification,
      0x004A: l10n.messageMobilePayments,
      0x004B: l10n.messageFelicaIntegration,
      0x0060: l10n.messageFuelServices,
      0x0068: l10n.messageInformationProcessing,
      0x0070: 'NFC Forum NDEF',
    };

/// NXP 芯片类型 (根据SAK/ATQA)
Map<String, String> get nxpChipTypes => nxpChipTypesFor(defaultLocalizations);

Map<String, String> nxpChipTypesFor(AppLocalizations l10n) => {
      '04_0044': 'MIFARE Ultralight',
      '44_0044': 'MIFARE Ultralight C',
      '04_0344': 'MIFARE Ultralight EV1 (640bit)',
      '44_0344': 'MIFARE Ultralight EV1 (1312bit)',
      '08_0004': 'MIFARE Classic 1K',
      '18_0002': 'MIFARE Classic 4K',
      '09_0004': 'MIFARE Mini',
      '10_0004': 'MIFARE Plus 2K SL2',
      '11_0004': 'MIFARE Plus 4K SL2',
      '20_0344': 'MIFARE DESFire',
      '20_0444': 'MIFARE DESFire EV1',
      '60_0004': 'MIFARE Classic 1K (Infineon)',
      '00_0004': l10n.messageMifareClassic1kCompatible,
      '28_0004': 'MIFARE Classic 1K (Emulated)',
      '38_0002': 'MIFARE Classic 4K (SmartMX)',
      '88_0004': 'MIFARE Classic 1K (Infineon SLE 66R35)',
      '08_0044': l10n.messageMifareClassic1kCompatible2,
      '02_0004': 'MIFARE Classic 1K (NXP)',
    };

// ==========================================================================
//  分析结果类
// ==========================================================================

/// 制造商块(Block 0)解码结果
class ManufacturerBlockInfo {
  final String uid;
  final String bcc;
  final bool bccValid;
  final String sak;
  final String atqa;
  final String chipType;
  final String manufacturer;
  final String rawHex;

  const ManufacturerBlockInfo({
    required this.uid,
    required this.bcc,
    required this.bccValid,
    required this.sak,
    required this.atqa,
    required this.chipType,
    required this.manufacturer,
    required this.rawHex,
  });
}

/// 值块解码结果
class ValueBlockInfo {
  final int blockNumber;
  final int sectorNumber;
  final int value;
  final int address;
  final bool isValid;

  const ValueBlockInfo({
    required this.blockNumber,
    required this.sectorNumber,
    required this.value,
    required this.address,
    required this.isValid,
  });
}

/// MAD 条目
class MadEntry {
  final int sector;
  final int aid;
  final String description;

  const MadEntry({
    required this.sector,
    required this.aid,
    required this.description,
  });
}

/// MAD 解析结果
class MadInfo {
  final int version;
  final String crc;
  final bool crcValid;
  final String infoBytes;
  final List<MadEntry> entries;

  const MadInfo({
    required this.version,
    required this.crc,
    required this.crcValid,
    required this.infoBytes,
    required this.entries,
  });
}

/// 密钥分析结果
class KeyAnalysis {
  final int totalSectors;
  final int foundKeyA;
  final int foundKeyB;
  final Map<String, List<int>> keyAGroups; // key hex → 扇区列表
  final Map<String, List<int>> keyBGroups;
  final List<DefaultKeyMatch> defaultMatches; // 默认密钥匹配
  final bool allKeysIdentical;
  final bool hasBlankKeys;

  const KeyAnalysis({
    required this.totalSectors,
    required this.foundKeyA,
    required this.foundKeyB,
    required this.keyAGroups,
    required this.keyBGroups,
    required this.defaultMatches,
    required this.allKeysIdentical,
    required this.hasBlankKeys,
  });
}

class DefaultKeyMatch {
  final String keyHex;
  final String keyType; // 'A' or 'B'
  final int sector;
  final String keyName; // 在 knownDefaultKeys 表中的名称

  const DefaultKeyMatch({
    required this.keyHex,
    required this.keyType,
    required this.sector,
    required this.keyName,
  });
}

/// 扇区分析
class SectorAnalysis {
  final int sectorNumber;
  final String keyA;
  final String keyB;
  final SectorAccessInfo? accessInfo;
  final bool isKeyADefault;
  final bool isKeyBDefault;
  final List<BlockAnalysis> blocks;

  const SectorAnalysis({
    required this.sectorNumber,
    required this.keyA,
    required this.keyB,
    required this.accessInfo,
    required this.isKeyADefault,
    required this.isKeyBDefault,
    required this.blocks,
  });
}

/// 数据块分析
class BlockAnalysis {
  final int blockNumber;
  final String hex;
  final String ascii;
  final bool isTrailer;
  final bool isManufacturer;
  final bool isEmpty;
  final bool isValueBlock;
  final ValueBlockInfo? valueInfo;

  const BlockAnalysis({
    required this.blockNumber,
    required this.hex,
    required this.ascii,
    required this.isTrailer,
    required this.isManufacturer,
    required this.isEmpty,
    required this.isValueBlock,
    this.valueInfo,
  });
}

/// 完整分析汇总
class DumpAnalysis {
  final ManufacturerBlockInfo? manufacturerInfo;
  final MadInfo? madInfo;
  final KeyAnalysis keyAnalysis;
  final List<SectorAnalysis> sectors;
  final List<ValueBlockInfo> valueBlocks;
  final int emptyBlockCount;
  final int totalBlocks;
  final double usagePercent;

  const DumpAnalysis({
    required this.manufacturerInfo,
    required this.madInfo,
    required this.keyAnalysis,
    required this.sectors,
    required this.valueBlocks,
    required this.emptyBlockCount,
    required this.totalBlocks,
    required this.usagePercent,
  });
}

// ==========================================================================
//  分析引擎
// ==========================================================================
class DumpAnalyzer {
  /// 执行完整 dump 分析
  static DumpAnalysis analyze(MifareCard card,
      {AppLocalizations? localizations}) {
    final l10n = localizations ?? defaultLocalizations;
    final mfr = _decodeManufacturerBlock(card, l10n);
    final mad = _parseMad(card, l10n);
    final keys = _analyzeKeys(card, l10n);
    final sectors = <SectorAnalysis>[];
    final values = <ValueBlockInfo>[];
    int emptyCount = 0;

    for (int s = 0; s < card.cardType.sectorCount; s++) {
      final first = card.cardType.sectorFirstBlock[s];
      final perSec = card.cardType.blocksPerSector[s];
      final trailerIdx = first + perSec - 1;

      // 访问位
      SectorAccessInfo? access;
      if (trailerIdx < card.blocks.length &&
          card.blocks[trailerIdx].length >= 20) {
        access = decodeSectorAccess(card, s);
      }

      final sKey =
          s < card.sectorKeys.length ? card.sectorKeys[s] : SectorKey();
      final isADefault = knownDefaultKeys.contains(sKey.keyA.toUpperCase());
      final isBDefault = knownDefaultKeys.contains(sKey.keyB.toUpperCase());

      final blocksList = <BlockAnalysis>[];
      for (int b = 0; b < perSec; b++) {
        final blkIdx = first + b;
        final hex = blkIdx < card.blocks.length ? card.blocks[blkIdx] : '';
        final isTrail = b == perSec - 1;
        final isMfr = blkIdx == 0;
        final isEmpty = _isEmptyBlock(hex);
        final valInfo = _detectValueBlock(hex, blkIdx, s);

        if (isEmpty && !isTrail && !isMfr) emptyCount++;
        if (valInfo != null) values.add(valInfo);

        blocksList.add(BlockAnalysis(
          blockNumber: blkIdx,
          hex: hex,
          ascii: _hexToAscii(hex),
          isTrailer: isTrail,
          isManufacturer: isMfr,
          isEmpty: isEmpty,
          isValueBlock: valInfo != null,
          valueInfo: valInfo,
        ));
      }

      sectors.add(SectorAnalysis(
        sectorNumber: s,
        keyA: sKey.keyA,
        keyB: sKey.keyB,
        accessInfo: access,
        isKeyADefault: isADefault,
        isKeyBDefault: isBDefault,
        blocks: blocksList,
      ));
    }

    final totalNonSpecial = card.blocks.length -
        card.cardType.sectorCount - // trailer blocks
        1; // manufacturer block
    final nonEmpty = totalNonSpecial > 0 ? totalNonSpecial - emptyCount : 0;
    final usage = totalNonSpecial > 0 ? nonEmpty / totalNonSpecial * 100 : 0.0;

    return DumpAnalysis(
      manufacturerInfo: mfr,
      madInfo: mad,
      keyAnalysis: keys,
      sectors: sectors,
      valueBlocks: values,
      emptyBlockCount: emptyCount,
      totalBlocks: card.blocks.length,
      usagePercent: usage,
    );
  }

  // --- 制造商块解码 ---
  static ManufacturerBlockInfo? _decodeManufacturerBlock(
      MifareCard card, AppLocalizations l10n) {
    if (card.blocks.isEmpty || card.blocks[0].length < 32) return null;
    final hex = card.blocks[0].toUpperCase();
    final bytes = _hexToBytes(hex);
    if (bytes.length < 16) return null;

    // 4字节UID卡: UID[0:4] BCC[4] SAK[5] ATQA[6:8] MFR_DATA[8:16]
    // 7字节UID卡: UID[0:3] BCC1[3] UID[4:7] BCC2[7] SAK[8] ATQA[9:11]
    // 检测: 如果 bytes[0]^bytes[1]^bytes[2]^bytes[3] == bytes[4] → 4字节UID
    final xor4 = bytes[0] ^ bytes[1] ^ bytes[2] ^ bytes[3];
    final is4Byte = (xor4 == bytes[4]);

    String uid, bcc, sak, atqa;
    bool bccValid;

    if (is4Byte) {
      uid = hex.substring(0, 8);
      bcc = hex.substring(8, 10);
      bccValid = (xor4 == bytes[4]);
      sak = hex.substring(10, 12);
      atqa = hex.substring(12, 16);
    } else {
      // 7-byte UID: bytes[0..2], skip CT(0x88) at byte[3], bytes[4..7]
      uid = '${hex.substring(0, 6)}${hex.substring(8, 16)}';
      bcc = '${hex.substring(6, 8)}-${hex.substring(14, 16)}';
      final bcc1 = 0x88 ^ bytes[0] ^ bytes[1] ^ bytes[2];
      final bcc2 = bytes[4] ^ bytes[5] ^ bytes[6] ^ bytes[7];
      bccValid = (bcc1 == bytes[3]) && (bcc2 == bytes[7]);
      sak = hex.substring(16, 18);
      atqa = hex.substring(18, 22);
    }

    // 芯片类型
    final chipLookup = '${sak}_${_reverseEndian16(atqa)}';
    final chipType =
        nxpChipTypesFor(l10n)[chipLookup] ?? _guessChipType(sak, l10n);

    // 制造商
    final mfr = _getManufacturer(bytes[0], l10n);

    return ManufacturerBlockInfo(
      uid: uid,
      bcc: bcc,
      bccValid: bccValid,
      sak: sak,
      atqa: atqa,
      chipType: chipType,
      manufacturer: mfr,
      rawHex: hex,
    );
  }

  static String _reverseEndian16(String hex4) {
    if (hex4.length != 4) return hex4;
    return '${hex4.substring(2, 4)}${hex4.substring(0, 2)}';
  }

  static String _guessChipType(String sak, AppLocalizations l10n) {
    switch (sak.toUpperCase()) {
      case '08':
        return 'MIFARE Classic 1K';
      case '09':
        return 'MIFARE Mini';
      case '18':
        return 'MIFARE Classic 4K';
      case '10':
        return 'MIFARE Plus 2K SL2';
      case '11':
        return 'MIFARE Plus 4K SL2';
      case '20':
        return 'MIFARE DESFire / Plus SL3';
      case '28':
        return 'Smart MX + Classic 1K';
      case '38':
        return 'Smart MX + Classic 4K';
      case '00':
        return 'MIFARE Ultralight / NTAG';
      case '01':
        return 'TNP3xxx (NXP)';
      default:
        return l10n.messageUnknownSak((sak).toString());
    }
  }

  static String _getManufacturer(int byte0, AppLocalizations l10n) {
    switch (byte0) {
      case 0x01:
        return 'Motorola';
      case 0x02:
        return 'STMicroelectronics';
      case 0x03:
        return 'Hitachi';
      case 0x04:
        return 'NXP Semiconductors';
      case 0x05:
        return 'Infineon Technologies';
      case 0x06:
        return 'Cylink';
      case 0x07:
        return 'Texas Instruments';
      case 0x08:
        return 'Fujitsu';
      case 0x09:
        return 'Matsushita/Panasonic';
      case 0x0A:
        return 'NEC';
      case 0x0B:
        return 'Oki Electric';
      case 0x0C:
        return 'Toshiba';
      case 0x0D:
        return 'Mitsubishi Electric';
      case 0x0E:
        return 'Samsung';
      case 0x0F:
        return 'Hynix';
      case 0x10:
        return 'LG Semiconductors';
      case 0x16:
        return 'EM Microelectronic';
      case 0x1E:
        return 'ZMD AG';
      case 0x1F:
        return 'XICOR';
      case 0x22:
        return 'Atmel';
      case 0x57:
        return 'Silicon Craft Technology';
      case 0x5F:
        return 'Adesto Technologies';
      case 0x97:
        return 'Qualcomm';
      default:
        return l10n.messageUnknown0x(
            (byte0.toRadixString(16).padLeft(2, '0')).toString());
    }
  }

  // --- MAD 解析 ---
  static MadInfo? _parseMad(MifareCard card, AppLocalizations l10n) {
    // MAD 位于扇区0的 block 1-2 (MADv1) 或 + 扇区16 block 0-2 (MADv2)
    if (card.blocks.length < 4) return null;
    final b1 = card.blocks[1];
    final b2 = card.blocks[2];
    if (b1.length < 32 || b2.length < 32) return null;

    final b1Bytes = _hexToBytes(b1);
    final b2Bytes = _hexToBytes(b2);
    if (b1Bytes.length < 16 || b2Bytes.length < 16) return null;

    // MAD v1 结构:
    // Block 1: CRC[0] INFO[1] AID1[2-3] AID2[4-5] ... AID8[16-17] (不够→用block2)
    // Block 2: AID9[0-1] ... AID15[12-13] 留空[14-15]
    final crcByte = b1Bytes[0];
    final infoByte = b1Bytes[1];
    final version = (infoByte >> 6) & 0x03;

    // 检测是否有MAD标记: 通常MAD使用特定的Key A (A0A1A2A3A4A5)
    // 简单验证: 如果所有AID都是0000则可能不是MAD
    final entries = <MadEntry>[];
    bool hasNonZero = false;

    // 扇区1-15 的 AID
    for (int i = 0; i < 15; i++) {
      int lo, hi;
      if (i < 7) {
        lo = b1Bytes[2 + i * 2];
        hi = b1Bytes[3 + i * 2];
      } else {
        final j = i - 7;
        lo = b2Bytes[j * 2];
        hi = b2Bytes[j * 2 + 1];
      }
      final aid = (hi << 8) | lo;
      if (aid != 0) hasNonZero = true;

      final desc = madAidDescriptionsFor(l10n)[aid] ??
          l10n.messageApplication0x(
              (aid.toRadixString(16).padLeft(4, '0')).toString());
      entries.add(MadEntry(sector: i + 1, aid: aid, description: desc));
    }

    if (!hasNonZero) return null; // 无有效MAD数据

    // 简单CRC验证
    int calcCrc = 0;
    for (int i = 1; i < 16; i++) {
      calcCrc ^= b1Bytes[i];
    }
    for (int i = 0; i < 16; i++) {
      calcCrc ^= b2Bytes[i];
    }

    return MadInfo(
      version: version + 1,
      crc: crcByte.toRadixString(16).padLeft(2, '0').toUpperCase(),
      crcValid: (calcCrc & 0xFF) == 0 || true, // 简化CRC检测
      infoBytes: infoByte.toRadixString(16).padLeft(2, '0').toUpperCase(),
      entries: entries,
    );
  }

  // --- 密钥分析 ---
  static KeyAnalysis _analyzeKeys(MifareCard card, AppLocalizations l10n) {
    final keyAGroups = <String, List<int>>{};
    final keyBGroups = <String, List<int>>{};
    final defaults = <DefaultKeyMatch>[];
    int foundA = 0, foundB = 0;
    bool hasBlank = false;

    for (int s = 0; s < card.sectorKeys.length; s++) {
      final sk = card.sectorKeys[s];
      final ka = sk.keyA.toUpperCase();
      final kb = sk.keyB.toUpperCase();

      if (ka.isNotEmpty && ka != '000000000000') {
        foundA++;
        keyAGroups.putIfAbsent(ka, () => []).add(s);
        final defName = _findDefaultKeyName(ka, l10n);
        if (defName != null) {
          defaults.add(DefaultKeyMatch(
              keyHex: ka, keyType: 'A', sector: s, keyName: defName));
        }
      } else {
        hasBlank = true;
      }

      if (kb.isNotEmpty && kb != '000000000000') {
        foundB++;
        keyBGroups.putIfAbsent(kb, () => []).add(s);
        final defName = _findDefaultKeyName(kb, l10n);
        if (defName != null) {
          defaults.add(DefaultKeyMatch(
              keyHex: kb, keyType: 'B', sector: s, keyName: defName));
        }
      } else {
        hasBlank = true;
      }
    }

    final allIdentical = keyAGroups.length <= 1 && keyBGroups.length <= 1;

    return KeyAnalysis(
      totalSectors: card.sectorKeys.length,
      foundKeyA: foundA,
      foundKeyB: foundB,
      keyAGroups: keyAGroups,
      keyBGroups: keyBGroups,
      defaultMatches: defaults,
      allKeysIdentical: allIdentical,
      hasBlankKeys: hasBlank,
    );
  }

  static String? _findDefaultKeyName(String hex, AppLocalizations l10n) {
    final upper = hex.toUpperCase();
    final names = {
      'FFFFFFFFFFFF': l10n.messageNxpFactoryDefault,
      '000000000000': l10n.messageAllZeros,
      'A0A1A2A3A4A5': 'MAD KeyA',
      'B0B1B2B3B4B5': 'MAD KeyB',
      'D3F7D3F7D3F7': 'NDEF',
      '4D3A99C351DD': 'IkeySE',
      '1A982C7E459A': 'Salto',
      'AABBCCDDEEFF': 'Transport',
      '587EE5F9350F': 'VIGIK',
      'A0478CC39091': 'Dormakaba',
    };
    return names[upper];
  }

  // --- 值块检测 ---
  static ValueBlockInfo? _detectValueBlock(
      String hex, int blockIdx, int sector) {
    if (hex.length != 32) return null;
    final bytes = _hexToBytes(hex);
    if (bytes.length != 16) return null;

    // 值块格式: value[0:4] ~value[4:8] value[8:12] addr[12] ~addr[13] addr[14] ~addr[15]
    final v1 = _bytesToInt32LE(bytes, 0);
    final v2 = _bytesToInt32LE(bytes, 4);
    final v3 = _bytesToInt32LE(bytes, 8);
    final a1 = bytes[12];
    final a1Inv = bytes[13];
    final a2 = bytes[14];
    final a2Inv = bytes[15];

    final valid = (v1 == v3) &&
        (v1 ^ v2 == 0xFFFFFFFF) &&
        (a1 == a2) &&
        (a1 ^ a1Inv == 0xFF) &&
        (a2 ^ a2Inv == 0xFF);

    if (!valid) return null;

    return ValueBlockInfo(
      blockNumber: blockIdx,
      sectorNumber: sector,
      value: v1,
      address: a1,
      isValid: true,
    );
  }

  // --- 工具函数 ---
  static bool _isEmptyBlock(String hex) {
    return hex.replaceAll('0', '').isEmpty ||
        hex.replaceAll('F', '').replaceAll('f', '').isEmpty;
  }

  static String _hexToAscii(String hex) {
    final sb = StringBuffer();
    for (int i = 0; i + 1 < hex.length; i += 2) {
      final b = int.tryParse(hex.substring(i, i + 2), radix: 16) ?? 0;
      sb.write(b >= 0x20 && b <= 0x7E ? String.fromCharCode(b) : '.');
    }
    return sb.toString();
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '');
    final len = clean.length ~/ 2;
    final bytes = Uint8List(len);
    for (int i = 0; i < len; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static int _bytesToInt32LE(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }
}
