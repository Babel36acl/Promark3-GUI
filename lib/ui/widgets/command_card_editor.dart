import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/l10n/l10n.dart';

/// 对命令采集草稿直接编辑；完整文件的分析/回写沿用转储查看器。
class CommandCardEditor extends StatefulWidget {
  const CommandCardEditor({super.key, this.openedCard});
  final MifareCard? openedCard;
  @override
  State<CommandCardEditor> createState() => _CommandCardEditorState();
}

class _CommandCardEditorState extends State<CommandCardEditor> {
  final _command = TextEditingController();
  int _sector = 0;
  String? _error;
  String? _savedPath;
  bool _running = false;

  void _showError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = error.toString();
      _savedPath = null;
    });
  }

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  Future<void> _edit(
      String title, String value, void Function(String) apply) async {
    final controller = TextEditingController(text: value);
    String? error;
    final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx, update) => AlertDialog(
                title: Text(title),
                content: SizedBox(
                    width: 540,
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                          errorText: error,
                          helperText: context.l10n
                              .messageSpacesAreAllowedMeansUnknownClearThe),
                    )),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.l10n.messageCancel)),
                  FilledButton(
                      onPressed: () {
                        try {
                          apply(controller.text);
                          Navigator.pop(ctx);
                        } catch (e) {
                          update(() => error = '$e');
                        }
                      },
                      child: Text(context.l10n.messageApply)),
                ],
              ),
            ));
    await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _save(String format) async {
    final app = context.read<AppState>();
    final card = app.commandCard;
    try {
      // Validate and snapshot before opening the dialog; output may continue arriving.
      final bytes = format == 'bin'
          ? card.exportBin()
          : format == 'key.bin'
              ? card.exportKeyBin()
              : null;
      final text = switch (format) {
        'json' => card.exportDraft(),
        'eml' => card.exportEml(),
        'dic' => card.exportDictionary(),
        _ => '',
      };
      final name = format == 'json'
          ? 'command-card.json'
          : 'hf-mf-${card.uid.isEmpty ? 'unknown' : card.uid}-${format == 'dic' || format == 'key.bin' ? 'key' : 'dump'}.${format == 'key.bin' ? 'bin' : format}';
      final path =
          await FileDialogService.pickSaveFilePath(suggestedName: name);
      if (path == null) return;
      if (bytes != null) {
        await File(path).writeAsBytes(bytes);
      } else {
        await File(path).writeAsString(text);
      }
      if (format == 'dic' || format == 'key.bin') {
        app.setPreferredMfKeyFile(path);
      }
      if (format == 'bin' || format == 'eml') app.setPreferredMfDumpFile(path);
      await app.scanForFiles();
      if (mounted) {
        setState(() {
          _error = null;
          _savedPath = path;
        });
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _load() async {
    final card = context.read<AppState>().commandCard;
    try {
      final path = await FileDialogService.pickSingleFilePath();
      if (path == null) return;
      card.importDraft(await File(path).readAsString());
      if (mounted) {
        setState(() {
          _sector = 0;
          _error = null;
          _savedPath = null;
        });
      }
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final card = app.commandCard;
    if (_sector >= card.type.sectorCount) _sector = 0;
    final first = card.type.sectorFirstBlock[_sector];
    final savedPath = _savedPath;
    final status = _error ??
        (savedPath == null ? null : context.l10n.messageSaved(savedPath));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(
          context.l10n.messageCommandResultsAreCollectedHereAutomaticallyClick),
      const SizedBox(height: 8),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(context.l10n.messageUidBlocksKeys(
                (card.type.label).toString(),
                (card.uid.isEmpty
                        ? context.l10n.messageNotIdentified
                        : card.uid)
                    .toString(),
                (card.blocks.length).toString(),
                (card.keysA.length + card.keysB.length).toString())),
            PopupMenuButton<CardType>(
              tooltip: context.l10n.messageNewCardSelectCapacity,
              onSelected: (type) => setState(() {
                card.clear(cardType: type);
                _sector = 0;
              }),
              itemBuilder: (_) => [
                for (final type in [cardMini, card1K, card2K, card4K])
                  PopupMenuItem(
                      value: type,
                      child: Text(context.l10n
                          .messageNewCardClearTheCurrentDraft(
                              (type.label).toString())))
              ],
              child: Chip(label: Text(context.l10n.messageNewCardCapacity)),
            ),
            OutlinedButton(
                onPressed: _load, child: Text(context.l10n.messageOpenDraft)),
            OutlinedButton(
                onPressed: () => _save('json'),
                child: Text(context.l10n.messageSaveDraft)),
            OutlinedButton(
                onPressed: () => _save('dic'),
                child: Text(context.l10n.messageExportKeyDictionary)),
            OutlinedButton(
                onPressed: () => _save('key.bin'),
                child: Text(context.l10n.messageExportKeyBin2)),
            if (widget.openedCard != null)
              OutlinedButton(
                  onPressed: () {
                    try {
                      card.importCard(widget.openedCard!);
                      setState(() => _sector = 0);
                    } catch (e) {
                      _showError(e);
                    }
                  },
                  child: Text(context.l10n.messageReplaceDraftWithTheOpenFile)),
            OutlinedButton(
                onPressed: () => _save('eml'),
                child: Text(context.l10n.messageExportEml2)),
            OutlinedButton(
                onPressed: () => _save('bin'),
                child: Text(context.l10n.messageExportBin2)),
          ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _command,
                decoration: InputDecoration(
                    labelText: context.l10n.messageDirectCommand,
                    hintText: context.l10n.messageForExampleHfMfChk1k,
                    border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        FilledButton(
            onPressed: !app.isConnected || _running
                ? null
                : () async {
                    if (_command.text.trim().isEmpty) return;
                    setState(() => _running = true);
                    try {
                      await app.sendCommand(_command.text.trim());
                    } finally {
                      if (mounted) setState(() => _running = false);
                    }
                  },
            child: Text(_running
                ? context.l10n.messageRunning
                : context.l10n.messageExecute)),
      ]),
      if (status != null)
        Padding(
            padding: const EdgeInsets.all(8), child: SelectableText(status)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        DropdownButton<int>(
            value: _sector,
            items: [
              for (var s = 0; s < card.type.sectorCount; s++)
                DropdownMenuItem(
                    value: s,
                    child: Text(context.l10n.messageSector((s).toString())))
            ],
            onChanged: (s) => setState(() => _sector = s!)),
        TextButton(
            onPressed: () => setState(card.keysToTrailers),
            child: Text(context.l10n.messageKeysTrailers)),
        TextButton(
            onPressed: () => setState(card.trailersToKeys),
            child: Text(context.l10n.messageTrailersKeys)),
      ]),
      for (final a in [true, false])
        ListTile(
          title: Text('Key ${a ? 'A' : 'B'}'),
          subtitle: Text(
              (a ? card.keysA : card.keysB)[_sector] ??
                  context.l10n.messageNotRead,
              style: const TextStyle(fontFamily: 'monospace')),
          trailing: const Icon(Icons.edit),
          onTap: () => _edit(
              context.l10n.messageSectorKey2(
                  (_sector).toString(), (a ? 'A' : 'B').toString()),
              (a ? card.keysA : card.keysB)[_sector] ?? '',
              (v) => card.editKey(_sector, a, v)),
        ),
      for (var b = first; b < first + card.type.blocksPerSector[_sector]; b++)
        ListTile(
          title: Text(context.l10n.messageBlock3(
              (b).toString(),
              (b == card.type.trailerBlock(_sector)
                      ? context.l10n.messageTrailer2
                      : '')
                  .toString())),
          subtitle: Text(card.blocks[b] ?? context.l10n.messageNotRead,
              style: const TextStyle(fontFamily: 'monospace')),
          trailing: const Icon(Icons.edit),
          onTap: () => _edit(context.l10n.messageBlock2((b).toString()),
              card.blocks[b] ?? '', (v) => card.editBlock(b, v)),
        ),
    ]);
  }
}
