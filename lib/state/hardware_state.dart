/// 硬件信息状态管理
library;

import 'package:flutter/foundation.dart';
import 'package:pm3gui/l10n/localized_messages.dart';

class HardwareState extends ChangeNotifier with LocalizedMessages {
  String hwModel = '';
  String hwFirmware = '';
  String hwBootrom = '';
  String hwMcu = '';
  String hwFlashSize = '';
  bool _hasSmartcard = false;
  String get hwSmartcard => _hasSmartcard ? l10n.messageInstalled : '';
  String hwFpga = '';
  String hwUniqueId = '';
  int hwFlashFree = 0;
  int hwFlashTotal = 0;
  bool hwInfoParsed = false;

  // 预编译正则表达式
  static final _modelRegex = RegExp(
    r'\[\s*(Proxmark3[^\]]*|RDV[^\]]*|PM3[^\]]*)\s*\]',
    caseSensitive: false,
  );

  static final _firmwareRegex = RegExp(
    r'firmware[.\s]+([\w/\-. ]+)',
    caseSensitive: false,
  );

  static final _bootromRegex = RegExp(
    r'bootrom[.\s]+([\w/\-. ]+)',
    caseSensitive: false,
  );

  static final _mcuRegex = RegExp(
    r'uC:\s*(AT\w+)',
    caseSensitive: false,
  );

  static final _flashSizeRegex = RegExp(
    r'Embedded\s+Flash\s*[:.]?\s*(\d+\w?)',
    caseSensitive: false,
  );

  static final _fpgaRegex = RegExp(
    r'FPGA\s+fingerprint[.\s]+([\w.\- ]+)',
    caseSensitive: false,
  );

  static final _uidRegex = RegExp(
    r'Unique\s+ID[.\s:]+([0-9A-Fa-f\s]+)',
    caseSensitive: false,
  );

  static final _memRegex = RegExp(
    r'(\d+)\s*/\s*(\d+)\s*bytes',
    caseSensitive: false,
  );

  void resetHwInfo() {
    hwModel = '';
    hwFirmware = '';
    hwBootrom = '';
    hwMcu = '';
    hwFlashSize = '';
    _hasSmartcard = false;
    hwFpga = '';
    hwUniqueId = '';
    hwFlashFree = 0;
    hwFlashTotal = 0;
    hwInfoParsed = false;
    notifyListeners();
  }

  void parseHwVersion(String output) {
    hwInfoParsed = true;

    // 解析设备型号
    final modelMatch = _modelRegex.firstMatch(output);
    if (modelMatch != null) {
      hwModel = modelMatch.group(1)!.trim();
    }

    // 解析固件版本
    final fwMatch = _firmwareRegex.firstMatch(output);
    if (fwMatch != null) {
      hwFirmware = fwMatch.group(1)!.trim();
    }

    // 解析 Bootrom 版本
    final bootMatch = _bootromRegex.firstMatch(output);
    if (bootMatch != null) {
      hwBootrom = bootMatch.group(1)!.trim();
    }

    // 解析 MCU 型号
    final mcuMatch = _mcuRegex.firstMatch(output);
    if (mcuMatch != null) {
      hwMcu = mcuMatch.group(1)!.trim();
    }

    // 解析 Flash 大小
    final flashMatch = _flashSizeRegex.firstMatch(output);
    if (flashMatch != null) {
      hwFlashSize = flashMatch.group(1)!.trim();
    }

    // 解析 FPGA 版本
    final fpgaMatch = _fpgaRegex.firstMatch(output);
    if (fpgaMatch != null) {
      hwFpga = fpgaMatch.group(1)!.trim();
    }

    // 解析唯一 ID
    final uidMatch = _uidRegex.firstMatch(output);
    if (uidMatch != null) {
      hwUniqueId = uidMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // 检查智能卡模块
    if (output.toLowerCase().contains('smartcard module (sim)')) {
      _hasSmartcard = true;
    }

    // 解析 Flash 内存使用情况
    final memMatch = _memRegex.firstMatch(output);
    if (memMatch != null) {
      hwFlashFree = int.tryParse(memMatch.group(1)!) ?? 0;
      hwFlashTotal = int.tryParse(memMatch.group(2)!) ?? 0;
    }

    notifyListeners();
  }
}
