/// Dump comparison page — compare two Mifare dump files side by side.
///
/// Highlights differences in block data, keys, and access bits.
library;

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/parsers/dump_parser.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/l10n/l10n.dart';

class DumpComparePage extends StatefulWidget {
  const DumpComparePage({super.key});

  @override
  State<DumpComparePage> createState() => _DumpComparePageState();
}

class _DumpComparePageState extends State<DumpComparePage> {
  MifareCard? _cardA;
  MifareCard? _cardB;
  String? _pathA;
  String? _pathB;
  String? _errorA;
  String? _errorB;
  bool _onlyDiffs = false;

  Future<void> _loadCard(bool isA) async {
    try {
      final path = await FileDialogService.pickSingleFilePath(
        desktopTypeGroups: const [
          fs.XTypeGroup(
            label: 'PM3 dump',
            extensions: ['eml', 'bin', 'json', 'dump'],
          ),
        ],
      );
      if (path == null) return;
      final result = await parseDumpFile(path);
      setState(() {
        if (isA) {
          _cardA = result.card;
          _pathA = path;
          _errorA = result.error;
        } else {
          _cardB = result.card;
          _pathB = path;
          _errorB = result.error;
        }
      });
    } catch (e) {
      setState(() {
        if (isA) {
          _errorA = '$e';
        } else {
          _errorB = '$e';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            ElevatedButton.icon(
              onPressed: () => _loadCard(true),
              icon: const Icon(Icons.file_open, size: 18),
              label: Text(context.l10n.messageOpenFileA),
            ),
            if (_pathA != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pathA!.split('/').last,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: 16),
            const Icon(Icons.compare_arrows, color: Colors.grey),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _loadCard(false),
              icon: const Icon(Icons.file_open, size: 18),
              label: Text(context.l10n.messageOpenFileB),
            ),
            if (_pathB != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pathB!.split('/').last,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: 16),
            FilterChip(
              label: Text(context.l10n.messageDifferencesOnly,
                  style: TextStyle(fontSize: 12)),
              selected: _onlyDiffs,
              onSelected: (v) => setState(() => _onlyDiffs = v),
            ),
          ]),
        ),
        // 错误信息
        if (_errorA != null)
          _errorBar(context.l10n.messageFileAError((_errorA).toString())),
        if (_errorB != null)
          _errorBar(context.l10n.messageFileBError((_errorB).toString())),
        const Divider(height: 1),

        // 对比内容
        if (_cardA != null && _cardB != null)
          Expanded(child: _buildCompareView())
        else
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.compare_arrows, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(context.l10n.messageOpenTwoDumpFilesToCompareThem,
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                SizedBox(height: 8),
                Text(context.l10n.messageSupportsEmlBinJsonDump,
                    style: TextStyle(color: Colors.grey)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _errorBar(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Colors.red.withValues(alpha: 0.1),
      child: Text(msg, style: const TextStyle(color: Colors.redAccent)),
    );
  }

  Widget _buildCompareView() {
    final maxBlocks = _cardA!.blocks.length > _cardB!.blocks.length
        ? _cardA!.blocks.length
        : _cardB!.blocks.length;

    // 统计差异
    int diffCount = 0;
    int diffKeyA = 0;
    int diffKeyB = 0;
    for (var i = 0; i < maxBlocks; i++) {
      final a = i < _cardA!.blocks.length ? _cardA!.blocks[i] : '';
      final b = i < _cardB!.blocks.length ? _cardB!.blocks[i] : '';
      if (a.toUpperCase() != b.toUpperCase()) diffCount++;
    }
    final maxSectors = _cardA!.sectorKeys.length > _cardB!.sectorKeys.length
        ? _cardA!.sectorKeys.length
        : _cardB!.sectorKeys.length;
    for (var s = 0; s < maxSectors; s++) {
      final ka1 =
          s < _cardA!.sectorKeys.length ? _cardA!.sectorKeys[s].keyA : '';
      final ka2 =
          s < _cardB!.sectorKeys.length ? _cardB!.sectorKeys[s].keyA : '';
      if (ka1.toUpperCase() != ka2.toUpperCase()) diffKeyA++;
      final kb1 =
          s < _cardA!.sectorKeys.length ? _cardA!.sectorKeys[s].keyB : '';
      final kb2 =
          s < _cardB!.sectorKeys.length ? _cardB!.sectorKeys[s].keyB : '';
      if (kb1.toUpperCase() != kb2.toUpperCase()) diffKeyB++;
    }

    return Column(
      children: [
        // 概况
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            _statChip(context.l10n.messageTotalBlocks, '$maxBlocks'),
            const SizedBox(width: 8),
            _statChip(context.l10n.messageDataDifferences,
                context.l10n.messageBlocks((diffCount).toString()),
                color: diffCount > 0 ? Colors.orange : Colors.green),
            const SizedBox(width: 8),
            _statChip(context.l10n.messageKeyADifferences, '$diffKeyA',
                color: diffKeyA > 0 ? Colors.orange : Colors.green),
            const SizedBox(width: 8),
            _statChip(context.l10n.messageKeyBDifferences, '$diffKeyB',
                color: diffKeyB > 0 ? Colors.orange : Colors.green),
            const Spacer(),
            Chip(
              avatar: const Icon(Icons.nfc, size: 14),
              label: Text(
                'A: ${_cardA!.uid}  vs  B: ${_cardB!.uid}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        // 逐块对比
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: maxBlocks,
            itemBuilder: (context, block) {
              final a = block < _cardA!.blocks.length
                  ? _cardA!.blocks[block]
                  : context.l10n.messageNone;
              final b = block < _cardB!.blocks.length
                  ? _cardB!.blocks[block]
                  : context.l10n.messageNone;
              final isDiff = a.toUpperCase() != b.toUpperCase();

              if (_onlyDiffs && !isDiff) return const SizedBox.shrink();

              // 判断块类型
              final isTrailerA = _cardA != null && block < _cardA!.blocks.length
                  ? _cardA!.isTrailerBlock(block)
                  : false;
              final isBlock0 = block == 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDiff
                      ? Colors.red.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isDiff
                      ? Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    // 块号
                    SizedBox(
                      width: 50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('B$block',
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          if (isBlock0)
                            Text(context.l10n.messageManufacturer,
                                style:
                                    TextStyle(fontSize: 9, color: Colors.blue)),
                          if (isTrailerA)
                            Text(context.l10n.messageTrailer,
                                style: TextStyle(
                                    fontSize: 9, color: Colors.orange)),
                        ],
                      ),
                    ),
                    // 文件 A
                    Expanded(
                      child: _buildDiffHex(a, b, isA: true),
                    ),
                    // 差异标记
                    SizedBox(
                      width: 30,
                      child: Center(
                        child: isDiff
                            ? const Icon(Icons.difference,
                                size: 14, color: Colors.redAccent)
                            : const Icon(Icons.check,
                                size: 14, color: Colors.green),
                      ),
                    ),
                    // 文件 B
                    Expanded(
                      child: _buildDiffHex(b, a, isA: false),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 高亮字节级差异
  Widget _buildDiffHex(String hex, String other, {required bool isA}) {
    if (hex.length < 2) {
      return Text(hex,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
    }
    final spans = <TextSpan>[];
    for (var i = 0; i < hex.length; i += 2) {
      final byte = hex.substring(i, (i + 2).clamp(0, hex.length));
      final otherByte = i < other.length
          ? other.substring(i, (i + 2).clamp(0, other.length))
          : '';
      final isDiff = byte.toUpperCase() != otherByte.toUpperCase();
      if (i > 0) spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(
        text: byte.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color:
              isDiff ? (isA ? Colors.orangeAccent : Colors.cyanAccent) : null,
          fontWeight: isDiff ? FontWeight.bold : null,
          backgroundColor: isDiff ? Colors.red.withValues(alpha: 0.15) : null,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _statChip(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}
