/// Dump viewer page — open/view/edit/export Mifare dump files.
///
/// This is the core offline feature — works without PM3 hardware.
/// Includes dump viewing, deep analysis, format conversion, and write-back.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:provider/provider.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/models/access_bits.dart';
import 'package:pm3gui/parsers/dump_parser.dart';
import 'package:pm3gui/parsers/eml_parser.dart';
import 'package:pm3gui/parsers/bin_parser.dart';
import 'package:pm3gui/parsers/json_dump_parser.dart';
import 'package:pm3gui/parsers/key_parser.dart';
import 'package:pm3gui/services/dump_converter.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/ui/widgets/command_card_editor.dart';
import 'package:pm3gui/l10n/l10n.dart';

enum _KeyOverride { preserve, overwrite }

enum _QuickWriteMode {
  auto,
  uid,
  cuid,
  fuid,
  gen1a,
  gen3,
  gen4,
}

class DumpViewerPage extends StatefulWidget {
  const DumpViewerPage({super.key});

  @override
  State<DumpViewerPage> createState() => _DumpViewerPageState();
}

class _DumpViewerPageState extends State<DumpViewerPage>
    with SingleTickerProviderStateMixin {
  MifareCard? _card;
  DumpResult? _dumpResult;
  String? _filePath;
  String? _error;
  String _format = '';
  int _selectedSector = 0;
  late TabController _tabController;

  // Converter state
  String? _convertInput;
  String? _convertInputFormat;
  DumpFormat? _convertTarget;
  String? _convertStatus;
  bool _converting = false;
  List<SectorKey>? _extractedKeys;
  String? _keySummary;

  // Editable block data controllers (per-sector)
  final Map<int, TextEditingController> _blockControllers = {};
  // Editable key controllers
  final Map<int, TextEditingController> _keyAControllers = {};
  final Map<int, TextEditingController> _keyBControllers = {};

  // Write-back state
  String _writeKeyType = 'B'; // default use Key B for auth
  bool _skipBlock0 = true;
  bool _writeTrailers = true;
  bool _processingExternalOpenRequest = false;
  _QuickWriteMode _quickWriteMode = _QuickWriteMode.auto;
  String _gen4Pwd = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _blockControllers.values) {
      c.dispose();
    }
    for (final c in _keyAControllers.values) {
      c.dispose();
    }
    for (final c in _keyBControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openFile() async {
    try {
      final path = await FileDialogService.pickSingleFilePath(
        desktopTypeGroups: const [
          fs.XTypeGroup(
            label: 'PM3 dump/key',
            extensions: ['eml', 'bin', 'json', 'dump', 'dic', 'txt'],
          ),
        ],
      );
      if (path == null) return;

      // ── Detect if it's a key-only file ──
      final isKey = await _isKeyFile(path);

      if (isKey) {
        // KEY file → only merge keys, never touch blocks
        await _loadKeyFileOnly(path);
      } else {
        // DUMP file → optionally preserve existing keys
        await _loadDumpFile(path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _error = context.l10n.messageCouldNotOpenFile(e.toString()));
    }
  }

  Future<void> _openPath(String path) async {
    try {
      final isKey = await _isKeyFile(path);
      if (isKey) {
        await _loadKeyFileOnly(path);
      } else {
        await _loadDumpFile(path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _error = context.l10n.messageCouldNotOpenFile(e.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(context.l10n.messageCouldNotOpenFile((e).toString()))),
      );
    }
  }

  void _consumePendingOpenRequest(AppState appState) {
    if (_processingExternalOpenRequest) return;
    final pending = appState.pendingIntent;
    if (pending == null || pending.page != AppPage.dumpViewer) return;

    _processingExternalOpenRequest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final intent = appState.takePendingIntentFor(AppPage.dumpViewer);
      if (intent != null && intent.action == 'open_file') {
        final path = intent.params['path'];
        if (path != null && path.trim().isNotEmpty) {
          await _openPath(path);
        }
      }
      _processingExternalOpenRequest = false;
    });
  }

  /// Detect if a file is a key-only file (.dic text, or .bin with key-file size).
  Future<bool> _isKeyFile(String path) async {
    final ext = path.split('.').last.toLowerCase();

    // .dic / .txt are always key files
    if (ext == 'dic') return true;

    // Check filename pattern: *-key*.bin
    final name = path.split('/').last.split('\\').last.toLowerCase();
    if (name.contains('-key') || name.endsWith('.keys.txt')) return true;

    // For .bin files, check if the size matches a key file layout
    if (ext == 'bin' || ext == 'dump') {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        // Key file sizes: sectorCount × 12
        const keySizes = {
          5 * 12, // MINI: 60
          16 * 12, // 1K: 192
          32 * 12, // 2K: 384
          40 * 12, // 4K: 480
        };
        if (keySizes.contains(size)) return true;
      }
    }

    return false;
  }

  /// Load a key-only file: merge keys into existing card without overwriting blocks.
  Future<void> _loadKeyFileOnly(String path) async {
    final ext = path.split('.').last.toLowerCase();
    List<SectorKey> newKeys;

    if (ext == 'dic') {
      // Text dictionary — extract unique keys (no sector mapping)
      final text = await File(path).readAsString();
      final keyList = parseDicString(text);
      // Show info only
      setState(() {
        _extractedKeys = null;
        _keySummary = context.l10n
            .messageDictionaryFileUniqueKeys((keyList.length).toString());
        _error = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n
                .messageDictionaryLoadedKeys((keyList.length).toString()))),
      );
      return;
    }

    // Binary key file
    if (ext == 'txt') {
      final l10n = context.l10n;
      newKeys =
          parseKeyText(await File(path).readAsString(), localizations: l10n);
    } else {
      final bytes = await File(path).readAsBytes();
      newKeys = parseKeyBinBytes(Uint8List.fromList(bytes));
    }

    if (_card != null) {
      // Merge keys into existing card WITHOUT touching block data
      _mergeKeys(newKeys);
      setState(() {
        _error = null;
        _initEditControllers();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .messageMergedKeysForSectorsBlockDataUnchanged(
                  (newKeys.length).toString())),
          backgroundColor: Colors.green.withValues(alpha: 0.8),
        ),
      );
    } else {
      final type = [cardMini, card1K, card2K, card4K]
          .firstWhere((type) => type.sectorCount == newKeys.length);
      if (!mounted) return;
      final draft = context.read<AppState>().commandCard;
      draft.clear(cardType: type);
      for (var s = 0; s < newKeys.length; s++) {
        draft.editKey(s, true, newKeys[s].keyA);
        draft.editKey(s, false, newKeys[s].keyB);
      }
      setState(() {
        _error = null;
      });
      _tabController.animateTo(4);
    }
  }

  /// Load a dump file, optionally preserving existing keys.
  Future<void> _loadDumpFile(String path) async {
    final dumpResult = await parseDumpFile(path);
    if (!mounted) return;
    if (!dumpResult.isSuccess) {
      setState(() => _error = dumpResult.error);
      return;
    }

    if (_card != null && _card!.sectorKeys.isNotEmpty) {
      // Already have a card with keys — ask user what to do
      if (!mounted) return;
      final choice = await _showKeyOverrideDialog();
      if (choice == null) return; // cancelled

      final oldKeys = _card!.sectorKeys
          .map((k) => SectorKey(keyA: k.keyA, keyB: k.keyB))
          .toList();

      setState(() {
        _dumpResult = dumpResult;
        _card = dumpResult.card;
        _filePath = path;
        _format = dumpResult.format;
        _error = dumpResult.error;
        _selectedSector = 0;
      });

      if (choice == _KeyOverride.preserve) {
        // Restore previously held keys
        _mergeKeys(oldKeys);
      }
      // else: choice == overwrite → use dump's own keys (already set)

      setState(() => _initEditControllers());
      if (!mounted) return;
      context.read<AppState>()
        ..updateCard(_card!)
        ..setPreferredMfDumpFile(path);
    } else {
      // No previous card — just load normally
      setState(() {
        _dumpResult = dumpResult;
        _card = dumpResult.card;
        _filePath = path;
        _format = dumpResult.format;
        _error = dumpResult.error;
        _selectedSector = 0;
        _initEditControllers();
      });
      if (!mounted) return;
      context.read<AppState>()
        ..updateCard(_card!)
        ..setPreferredMfDumpFile(path);
    }
  }

  /// Merge keys from [newKeys] into the current card's sectorKeys.
  void _mergeKeys(List<SectorKey> newKeys) {
    if (_card == null) return;
    final limit = _card!.sectorKeys.length < newKeys.length
        ? _card!.sectorKeys.length
        : newKeys.length;
    for (var s = 0; s < limit; s++) {
      _card!.sectorKeys[s].keyA = newKeys[s].keyA;
      _card!.sectorKeys[s].keyB = newKeys[s].keyB;
    }
  }

  /// Show dialog asking whether to overwrite keys when loading a dump file.
  Future<_KeyOverride?> _showKeyOverrideDialog() async {
    return showDialog<_KeyOverride>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.vpn_key, size: 20),
          SizedBox(width: 8),
          Text(context.l10n.messageKeyHandling),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              context.l10n.messageKeyDataIsAlreadyLoadedHowShould,
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.messageDumpKeyFieldsAreOftenFfWhile,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.messageCancel),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, _KeyOverride.preserve),
            icon: const Icon(Icons.shield, size: 16),
            label: Text(context.l10n.messageKeepCurrentKeys),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, _KeyOverride.overwrite),
            icon: const Icon(Icons.sync, size: 16),
            label: Text(context.l10n.messageReplaceWithDumpKeys),
          ),
        ],
      ),
    );
  }

  Future<void> _setAsPreferredKeyFile() async {
    if (_card == null) return;
    if (!_applyEdits()) return;
    final appState = context.read<AppState>();
    final tmp = File('${Directory.systemTemp.path}/pm3gui-current-keys.bin');
    await tmp.writeAsBytes(exportKeysToBin(_card!.sectorKeys), flush: true);
    appState.setPreferredMfKeyFile(tmp.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                context.l10n.messageDefaultKeyFileSet((tmp.path).toString()))),
      );
    }
  }

  Future<void> _setAsPreferredDumpFile() async {
    if (_card == null) return;
    if (!_applyEdits()) return;
    final appState = context.read<AppState>();
    final tmp = File('${Directory.systemTemp.path}/pm3gui-current-dump.bin');
    await tmp.writeAsBytes(exportToBin(_card!), flush: true);
    appState.setPreferredMfDumpFile(tmp.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                context.l10n.messageDefaultDumpFileSet((tmp.path).toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _consumePendingOpenRequest(appState);

    return Column(
      children: [
        _buildToolbar(),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.red.withValues(alpha: 0.1),
            child:
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        if (_filePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$_filePath (format: $_format)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        const Divider(height: 1),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(
                text: context.l10n.messageSectorView,
                icon: Icon(Icons.grid_view, size: 18)),
            Tab(
                text: context.l10n.messageKeysEdit,
                icon: Icon(Icons.edit, size: 18)),
            Tab(
                text: context.l10n.messageDetailedAnalysis,
                icon: Icon(Icons.analytics, size: 18)),
            Tab(
                text: context.l10n.messageWriteClear,
                icon: Icon(Icons.upload, size: 18)),
            Tab(
                text: context.l10n.messageCommandData,
                icon: Icon(Icons.terminal, size: 18)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _card != null
                  ? Row(children: [
                      SizedBox(width: 80, child: _buildSectorList()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildSectorView()),
                    ])
                  : _buildEmptyHint(
                      context.l10n.messageOpenADumpFileToViewSector,
                      Icons.grid_view),
              _card != null
                  ? _buildKeyEditorView()
                  : _buildEmptyHint(
                      context.l10n.messageOpenADumpOrKeyFileTo, Icons.edit),
              _card != null
                  ? _buildAnalysisView()
                  : _buildEmptyHint(
                      context.l10n.messageOpenADumpFileToViewDetailed,
                      Icons.analytics),
              _buildWriteBackView(),
              CommandCardEditor(openedCard: _card),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHint(String message, IconData icon) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 15)),
        const SizedBox(height: 8),
        Text(context.l10n.messageSupportsEmlBinJsonDumpDic,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openFile,
          icon: const Icon(Icons.file_open, size: 16),
          label: Text(context.l10n.messageOpenFile),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _tabController.animateTo(4),
          icon: const Icon(Icons.terminal),
          label: Text(context.l10n.messageCommandData),
        ),
      ]),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        ElevatedButton.icon(
          onPressed: _openFile,
          icon: const Icon(Icons.file_open, size: 18),
          label: Text(context.l10n.messageOpenFile),
        ),
        const SizedBox(width: 8),
        if (_card != null) ...[
          OutlinedButton.icon(
            onPressed: _setAsPreferredKeyFile,
            icon: const Icon(Icons.vpn_key, size: 16),
            label: Text(context.l10n.messageSetAsDefaultKeys),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _setAsPreferredDumpFile,
            icon: const Icon(Icons.save, size: 16),
            label: Text(context.l10n.messageSetAsDefaultDump),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: _exportAs,
            child: Chip(
              avatar: Icon(Icons.save_alt, size: 18),
              label: Text(context.l10n.messageExportAs),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'eml', child: Text(context.l10n.messageEmlTextDump)),
              PopupMenuItem(
                  value: 'bin', child: Text(context.l10n.messageBinBinaryDump)),
              PopupMenuItem(
                  value: 'json',
                  child: Text(context.l10n.messageJsonPm3Format)),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'key.bin',
                  child: Text(context.l10n.messageKeyBinBinaryKeys)),
              PopupMenuItem(
                  value: 'dic',
                  child: Text(context.l10n.messageDicKeyDictionary)),
              PopupMenuItem(
                  value: 'keys.txt',
                  child: Text(context.l10n.messageKeysTxtKeyList)),
            ],
          ),
          const Spacer(),
          Chip(
            avatar: const Icon(Icons.nfc, size: 18),
            label: Text(
              '${_card!.cardType.label} | UID: ${_card!.uid}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _exportAs(String format) async {
    if (_card == null) return;

    if (!_applyEdits()) return;
    final appState = context.read<AppState>();

    final autoPath = _buildCategorizedExportPath(format, appState);
    try {
      if (!await File(autoPath).exists()) {
        await _writeExportToPath(autoPath, format);
        _afterExportSuccess(autoPath, format, appState, autoSaved: true);
        return;
      }
    } catch (_) {
      // fallback to manual save
    }

    final savePath = await FileDialogService.pickSaveFilePath(
      suggestedName: _suggestedExportFileName(format),
    );
    if (savePath == null) return;

    try {
      await _writeExportToPath(savePath, format);
      _afterExportSuccess(savePath, format, appState, autoSaved: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.messageExportFailed((e).toString()))));
      }
    }
  }

  String _suggestedExportFileName(String format) {
    final uid = _card!.uid.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    return switch (format) {
      'eml' => 'hf-mf-$uid-dump.eml',
      'bin' => 'hf-mf-$uid-dump.bin',
      'json' => 'hf-mf-$uid-dump.json',
      'key.bin' => 'hf-mf-$uid-key.bin',
      'dic' => 'hf-mf-$uid-key.dic',
      'keys.txt' => 'hf-mf-$uid-keys.txt',
      _ => 'hf-mf-$uid-export.dat',
    };
  }

  String _buildCategorizedExportPath(String format, AppState appState) {
    final uid = _card!.uid.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final baseDir = (appState.collectBaseDir != null &&
            appState.collectBaseDir!.trim().isNotEmpty)
        ? appState.collectBaseDir!.trim()
        : '${Directory.current.path}/pm3_files';
    return '$baseDir/hf-mf/$uid/${_suggestedExportFileName(format)}';
  }

  Future<void> _writeExportToPath(String path, String format) async {
    await File(path).parent.create(recursive: true);
    switch (format) {
      case 'eml':
        await File(path).writeAsString(exportToEml(_card!));
      case 'bin':
        await File(path).writeAsBytes(exportToBin(_card!));
      case 'json':
        await File(path).writeAsString(exportToJson(_card!));
      case 'key.bin':
        await File(path).writeAsBytes(exportKeysToBin(_card!.sectorKeys));
      case 'dic':
        await File(path).writeAsString(
          exportToDic(_card!.sectorKeys, header: 'UID: ${_card!.uid}'),
        );
      case 'keys.txt':
        await File(path).writeAsString(exportKeysAsText(_card!.sectorKeys));
    }
  }

  void _afterExportSuccess(
    String savePath,
    String format,
    AppState appState, {
    required bool autoSaved,
  }) {
    const baseMarker = '/hf-mf/';
    if (savePath.contains(baseMarker)) {
      final baseDir = savePath.substring(0, savePath.indexOf(baseMarker));
      appState.setCollectBaseDir(baseDir);
    }

    if (format == 'key.bin') {
      appState.setPreferredMfKeyFile(savePath);
    }
    if (format == 'bin') {
      appState.setPreferredMfDumpFile(savePath);
    }
    appState.scanForFiles();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            autoSaved
                ? context.l10n
                    .messageExportedAndOrganized((savePath).toString())
                : context.l10n.messageExported((savePath).toString()),
          ),
        ),
      );
    }
  }

  Widget _buildSectorList() {
    return ListView.builder(
      itemCount: _card!.cardType.sectorCount,
      itemBuilder: (context, index) {
        final isSelected = index == _selectedSector;
        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          title: Text('Sec $index',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : null)),
          onTap: () => setState(() => _selectedSector = index),
        );
      },
    );
  }

  Widget _buildSectorView() {
    if (_card == null) {
      return Center(child: Text(context.l10n.messageNoCardData));
    }
    final ct = _card!.cardType;
    final sector = _selectedSector;
    final firstBlock = ct.sectorFirstBlock[sector];
    final blockCount = ct.blocksPerSector[sector];
    final trailerBlockIdx = ct.trailerBlock(sector);

    SectorAccessInfo? accessInfo;
    try {
      accessInfo = decodeSectorAccess(_card!, sector);
      if (!accessInfo.isValid) accessInfo = null;
    } catch (_) {}

    final sectorKey = _card!.sectorKeys[sector];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            context.l10n.messageSectorBlocks((sector).toString(),
                (firstBlock).toString(), (trailerBlockIdx).toString()),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(children: [
          _keyChip('Key A', sectorKey.keyA),
          const SizedBox(width: 8),
          _keyChip('Key B', sectorKey.keyB)
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < blockCount; i++)
          _buildBlockRow(
              firstBlock + i, firstBlock + i == trailerBlockIdx, accessInfo, i),
        if (accessInfo != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          Text(context.l10n.messageAccessConditions,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildAccessTable(accessInfo),
        ],
      ]),
    );
  }

  Widget _buildBlockRow(int block, bool isTrailer, SectorAccessInfo? accessInfo,
      int blockInSector) {
    final data =
        (block < _card!.blocks.length) ? _card!.blocks[block] : '??' * 16;
    Color bgColor = Colors.transparent;
    String label = 'Data';
    if (block == 0 && _selectedSector == 0) {
      label = context.l10n.messageManufacturerBlock;
      bgColor = Colors.blue.withValues(alpha: 0.1);
    } else if (isTrailer) {
      label = context.l10n.messageTrailer;
      bgColor = Colors.orange.withValues(alpha: 0.1);
    }

    int? cValue;
    if (accessInfo != null) {
      if (isTrailer) {
        cValue = accessInfo.trailerBits;
      } else if (blockInSector < accessInfo.dataBlockBits.length) {
        cValue = accessInfo.dataBlockBits[blockInSector];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        SizedBox(
            width: 50,
            child: Text('B$block',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 13))),
        SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
        Expanded(
            child: isTrailer
                ? _buildTrailerRow(data)
                : Text(_fmtHex(data),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13))),
        if (cValue != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4)),
            child: Text('C$cValue',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _buildTrailerRow(String data) {
    if (data.length < 32) {
      return Text(_fmtHex(data),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13));
    }
    final keyA = data.substring(0, 12);
    final access = data.substring(12, 20);
    final keyB = data.substring(20, 32);
    return Row(children: [
      Text(_fmtHex(keyA),
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.greenAccent)),
      const Text(' '),
      Text(_fmtHex(access),
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.orangeAccent)),
      const Text(' '),
      Text(_fmtHex(keyB),
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, color: Colors.cyanAccent)),
    ]);
  }

  Widget _buildAccessTable(SectorAccessInfo info) {
    final allBits = [...info.dataBlockBits, info.trailerBits];
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FixedColumnWidth(40),
        2: FlexColumnWidth()
      },
      children: [
        TableRow(
            decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
            children: [
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(context.l10n.messageBlock,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('C',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(context.l10n.messageDescription,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
        for (var i = 0; i < allBits.length; i++)
          TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                    i == allBits.length - 1
                        ? context.l10n.messageTrailer
                        : context.l10n.messageData((i).toString()),
                    style: const TextStyle(fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text('${allBits[i]}',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                    _accessDesc(allBits[i], isTrailer: i == allBits.length - 1),
                    style: const TextStyle(fontSize: 12))),
          ]),
      ],
    );
  }

  String _accessDesc(int c, {bool isTrailer = false}) {
    if (isTrailer) {
      final d = {
        0: context.l10n.messageKeyAWriteKeyAAccessBits,
        1: context.l10n.messageKeyAWriteKeyAAccessBits2,
        2: context.l10n.messageReadAccessBitsOnly,
        3: context.l10n.messageKeyAWriteAccessBitsKeyB,
        4: context.l10n.messageKeyAWriteKeyAAccessBits2,
        5: context.l10n.messageKeyBWriteAll,
        6: context.l10n.messageLocked,
        7: context.l10n.messageLocked
      };
      return d[c] ?? context.l10n.messageUnknown;
    }
    final d = {
      0: context.l10n.messageReadWriteWithKeyAOrB,
      1: context.l10n.messageReadWithABNoWriting,
      2: context.l10n.messageReadWithABNoWriting,
      3: context.l10n.messageReadWriteWithKeyBOnly,
      4: context.l10n.messageReadABWriteBDecrementA,
      5: context.l10n.messageReadWithKeyBOnly,
      6: context.l10n.messageReadABWriteIncrementBDecrement,
      7: context.l10n.messageLocked
    };
    return d[c] ?? context.l10n.messageUnknown;
  }

  Widget _keyChip(String label, String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        Text(key.isEmpty ? '------' : key,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: key.isEmpty ? Colors.grey : Colors.white)),
      ]),
    );
  }

  String _fmtHex(String hex) {
    final buf = StringBuffer();
    for (var i = 0; i < hex.length; i += 2) {
      if (i > 0) buf.write(' ');
      buf.write(hex.substring(i, (i + 2).clamp(0, hex.length)));
    }
    return buf.toString();
  }

  // ======================================================================
  //  深度分析视图
  // ======================================================================
  Widget _buildAnalysisView() {
    if (_dumpResult == null || _card == null) {
      return Center(child: Text(context.l10n.messageNoData));
    }
    final a = _dumpResult!.analysisFor(context.l10n);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // --- 概览卡片
        _analysisCard(context.l10n.messageOverview, [
          _kvRow(context.l10n.messageCardType, _card!.cardType.label),
          _kvRow('UID',
              _card!.uid.isNotEmpty ? _card!.uid : context.l10n.messageUnknown),
          _kvRow(context.l10n.messageTotalBlocks, '${a.totalBlocks}'),
          _kvRow(context.l10n.messageEmptyDataBlocks, '${a.emptyBlockCount}'),
          _kvRow(context.l10n.messageDataUsage,
              '${a.usagePercent.toStringAsFixed(1)}%'),
          _kvRow(context.l10n.messageValueBlocks, '${a.valueBlocks.length}'),
        ]),
        const SizedBox(height: 12),

        // --- 制造商信息
        if (a.manufacturerInfo != null)
          _analysisCard(context.l10n.messageManufacturerBlockBlock0, [
            _kvRow('UID', a.manufacturerInfo!.uid),
            _kvRow('BCC',
                '${a.manufacturerInfo!.bcc} ${a.manufacturerInfo!.bccValid ? "✅" : "❌"}'),
            _kvRow('SAK', a.manufacturerInfo!.sak),
            _kvRow('ATQA', a.manufacturerInfo!.atqa),
            _kvRow(context.l10n.messageChipType, a.manufacturerInfo!.chipType),
            _kvRow(context.l10n.messageManufacturer,
                a.manufacturerInfo!.manufacturer),
            _kvRow(context.l10n.messageRawData,
                _fmtHex(a.manufacturerInfo!.rawHex)),
          ]),
        if (a.manufacturerInfo != null) const SizedBox(height: 12),

        // --- 密钥分析
        _analysisCard(context.l10n.messageKeyAnalysis, [
          _kvRow(context.l10n.messageTotalSectors,
              '${a.keyAnalysis.totalSectors}'),
          _kvRow(context.l10n.messageKnownKeyA,
              '${a.keyAnalysis.foundKeyA} / ${a.keyAnalysis.totalSectors}'),
          _kvRow(context.l10n.messageKnownKeyB,
              '${a.keyAnalysis.foundKeyB} / ${a.keyAnalysis.totalSectors}'),
          _kvRow(
              context.l10n.messageAllKeysIdentical,
              a.keyAnalysis.allKeysIdentical
                  ? context.l10n.messageYes
                  : context.l10n.messageNo),
          _kvRow(
              context.l10n.messageContainsBlankKeys,
              a.keyAnalysis.hasBlankKeys
                  ? context.l10n.messageYes2
                  : context.l10n.messageNo),
          if (a.keyAnalysis.keyAGroups.isNotEmpty) ...[
            const Divider(),
            Text(context.l10n.messageKeyAGroups,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            for (final e in a.keyAnalysis.keyAGroups.entries)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                    context.l10n.messageSectors(
                        (e.key).toString(), (e.value.join(", ")).toString()),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
          if (a.keyAnalysis.keyBGroups.isNotEmpty) ...[
            const Divider(),
            Text(context.l10n.messageKeyBGroups,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            for (final e in a.keyAnalysis.keyBGroups.entries)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                    context.l10n.messageSectors(
                        (e.key).toString(), (e.value.join(", ")).toString()),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
          if (a.keyAnalysis.defaultMatches.isNotEmpty) ...[
            const Divider(),
            Text(context.l10n.messageDefaultKeyMatches,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orangeAccent)),
            for (final m in a.keyAnalysis.defaultMatches)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                    context.l10n.messageSectorKey(
                        (m.sector).toString(),
                        (m.keyType).toString(),
                        (m.keyHex).toString(),
                        (m.keyName).toString()),
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.orangeAccent)),
              ),
          ],
        ]),
        const SizedBox(height: 12),

        // --- MAD
        if (a.madInfo != null)
          _analysisCard(
              context.l10n.messageMadApplicationDirectoryV(
                  (a.madInfo!.version).toString()),
              [
                _kvRow('CRC', a.madInfo!.crc),
                _kvRow('Info', a.madInfo!.infoBytes),
                const Divider(),
                for (final e in a.madInfo!.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      SizedBox(
                          width: 60,
                          child: Text(
                              context.l10n.messageSector((e.sector).toString()),
                              style: const TextStyle(fontSize: 12))),
                      SizedBox(
                          width: 80,
                          child: Text(
                              '0x${e.aid.toRadixString(16).padLeft(4, '0')}',
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12))),
                      Expanded(
                          child: Text(e.description,
                              style: const TextStyle(fontSize: 12))),
                    ]),
                  ),
              ]),
        if (a.madInfo != null) const SizedBox(height: 12),

        // --- 值块
        if (a.valueBlocks.isNotEmpty)
          _analysisCard(context.l10n.messageValueBlocks2, [
            for (final v in a.valueBlocks)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  SizedBox(
                      width: 80,
                      child: Text(
                          context.l10n
                              .messageBlock2((v.blockNumber).toString()),
                          style: const TextStyle(fontSize: 12))),
                  SizedBox(
                      width: 100,
                      child: Text(
                          context.l10n
                              .messageSector((v.sectorNumber).toString()),
                          style: const TextStyle(fontSize: 12))),
                  Expanded(
                      child: Text(
                          context.l10n.messageValueAddress(
                              (v.value).toString(), (v.address).toString()),
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold))),
                ]),
              ),
          ]),
        if (a.valueBlocks.isNotEmpty) const SizedBox(height: 12),

        // --- 扇区概览表
        _analysisCard(context.l10n.messageSectorOverview, [
          for (final s in a.sectors)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                SizedBox(
                    width: 50,
                    child: Text('S${s.sectorNumber}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12))),
                SizedBox(
                    width: 110,
                    child: Text('A:${s.keyA}',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: s.isKeyADefault
                                ? Colors.orangeAccent
                                : Colors.greenAccent))),
                SizedBox(
                    width: 110,
                    child: Text('B:${s.keyB}',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: s.isKeyBDefault
                                ? Colors.orangeAccent
                                : Colors.cyanAccent))),
                if (s.accessInfo != null)
                  Text(
                      s.accessInfo!.isValid
                          ? context.l10n.messageValidAccessBits
                          : context.l10n.messageInvalidAccessBits,
                      style: const TextStyle(fontSize: 11))
                else
                  Text(context.l10n.messageNoAccessBits,
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),

        // --- 数据块 ASCII
        _analysisCard(context.l10n.messageDataBlockAsciiView, [
          for (final s in a.sectors)
            for (final b in s.blocks.where((x) => !x.isTrailer && !x.isEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Row(children: [
                  SizedBox(
                      width: 50,
                      child: Text('B${b.blockNumber}',
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.grey))),
                  Expanded(
                      child: Text(b.ascii,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12))),
                ]),
              ),
        ]),
      ]),
    );
  }

  Widget _analysisCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ]),
      ),
    );
  }

  Widget _kvRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        SizedBox(
            width: 120,
            child: Text(key,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]))),
        Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
      ]),
    );
  }

  // ======================================================================
  //  格式转换 & 密钥提取视图
  // ======================================================================
  Widget _buildConverterView() {
    if (_card == null) return Center(child: Text(context.l10n.messageNoData));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- 一键导出全部格式 ----
        _analysisCard(context.l10n.messageExportAllFormats, [
          Text(context.l10n.messageExportTheCurrentDumpInAllSupported,
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _exportButton(
                context.l10n.messageExportEml, Icons.text_snippet, 'eml'),
            _exportButton(context.l10n.messageExportBin, Icons.memory, 'bin'),
            _exportButton(
                context.l10n.messageExportJson, Icons.data_object, 'json'),
            _exportButton(
                context.l10n.messageExportKeyBin, Icons.key, 'key.bin'),
            _exportButton(context.l10n.messageExportDic, Icons.list_alt, 'dic'),
            _exportButton(context.l10n.messageExportKeysTxt, Icons.text_fields,
                'keys.txt'),
          ]),
        ]),
        const SizedBox(height: 16),

        // ---- 密钥提取 ----
        _analysisCard(context.l10n.messageKeyExtraction, [
          Text(context.l10n.messageAllKeysExtractedFromTheCurrentDump,
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          _buildKeyTable(),
          const SizedBox(height: 12),
          Wrap(runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _copyKeysToClipboard(),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(context.l10n.messageCopyAllKeys),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _copyKeysToClipboard(keyAOnly: true),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(context.l10n.messageKeyAOnly),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _copyKeysToClipboard(keyBOnly: true),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(context.l10n.messageKeyBOnly),
            ),
          ]),
        ]),
        const SizedBox(height: 16),

        // ---- 独立格式转换 ----
        _analysisCard(context.l10n.messageFileFormatConversion, [
          Text(context.l10n.messageSelectADumpOrKeyFileTo,
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),

          // Source file
          Row(children: [
            ElevatedButton.icon(
              onPressed: _pickConvertSource,
              icon: const Icon(Icons.file_open, size: 16),
              label: Text(context.l10n.messageSelectSourceFile),
            ),
            const SizedBox(width: 8),
            if (_convertInput != null)
              Expanded(
                child: Text(
                  _convertInput!.split('/').last,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ]),
          const SizedBox(height: 8),

          // Target format
          if (_convertInput != null) ...[
            Text(context.l10n.messageTargetFormat,
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final fmt in _getAvailableTargets())
                ChoiceChip(
                  label: Text(fmt.localizedLabel(context.l10n),
                      style: const TextStyle(fontSize: 12)),
                  selected: _convertTarget == fmt,
                  onSelected: (sel) {
                    if (sel) setState(() => _convertTarget = fmt);
                  },
                ),
            ]),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  _convertTarget != null && !_converting ? _doConvert : null,
              icon: _converting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.swap_horiz, size: 16),
              label: Text(_converting
                  ? context.l10n.messageConverting
                  : context.l10n.messageStartConversion),
            ),
          ],

          // Status
          if (_convertStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _convertStatus!.startsWith('✅')
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_convertStatus!,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ]),
        const SizedBox(height: 16),

        // ---- 密钥比对 -----
        if (_extractedKeys != null)
          _analysisCard(context.l10n.messageExternalKeyFile, [
            Text(context.l10n.messageLoadedExternalKeys,
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            _buildExternalKeyTable(),
            const SizedBox(height: 8),
            if (_keySummary != null)
              Text(_keySummary!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),

        // ---- 格式说明 ----
        const SizedBox(height: 16),
        _analysisCard(context.l10n.messageFormatReference, [
          _fmtDesc('.bin', context.l10n.messageRawBinaryDump16BytesPerBlock),
          _fmtDesc('.eml', context.l10n.messageTextDump32HexDigitsPerLine),
          _fmtDesc('.json',
              context.l10n.messagePm3JsonFormatIncludingCardMetadataAnd),
          _fmtDesc('.key.bin', context.l10n.messageBinaryKeyFile6ByteKeyA),
          _fmtDesc('.dic', context.l10n.messageKeyDictionaryOneKeyPerLineUsed),
          _fmtDesc('.keys.txt',
              context.l10n.messageReadableKeyTableSectorNumberKeyA),
        ]),
      ]),
    );
  }

  Widget _exportButton(String label, IconData icon, String format) {
    return OutlinedButton.icon(
      onPressed: () => _exportAs(format),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _fmtDesc(String ext, String desc) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 80,
            child: Text(ext,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold))),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  // ---- Key table for current dump ----
  Widget _buildKeyTable() {
    if (_card == null) return const SizedBox();
    final keys = _card!.sectorKeys;
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        TableRow(
            decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
            children: [
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(context.l10n.messageSector2,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Key A',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Key B',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
        for (var i = 0; i < keys.length; i++)
          TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text('$i',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: SelectableText(keys[i].keyA.toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _isKnownDefault(keys[i].keyA)
                            ? Colors.orangeAccent
                            : Colors.greenAccent))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: SelectableText(keys[i].keyB.toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _isKnownDefault(keys[i].keyB)
                            ? Colors.orangeAccent
                            : Colors.cyanAccent))),
          ]),
      ],
    );
  }

  Widget _buildExternalKeyTable() {
    if (_extractedKeys == null) return const SizedBox();
    final keys = _extractedKeys!;
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        TableRow(
            decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
            children: [
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(context.l10n.messageSector2,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Key A',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Key B',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
        for (var i = 0; i < keys.length; i++)
          TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text('$i',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(keys[i].keyA.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(keys[i].keyB.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
          ]),
      ],
    );
  }

  bool _isKnownDefault(String key) {
    const defaults = {
      'FFFFFFFFFFFF',
      '000000000000',
      'A0A1A2A3A4A5',
      'B0B1B2B3B4B5',
      'D3F7D3F7D3F7',
      'AABBCCDDEEFF',
    };
    return defaults.contains(key.toUpperCase());
  }

  void _copyKeysToClipboard({bool keyAOnly = false, bool keyBOnly = false}) {
    if (_card == null) return;
    final buf = StringBuffer();
    for (var i = 0; i < _card!.sectorKeys.length; i++) {
      final k = _card!.sectorKeys[i];
      if (keyAOnly) {
        buf.writeln(k.keyA.toUpperCase());
      } else if (keyBOnly) {
        buf.writeln(k.keyB.toUpperCase());
      } else {
        buf.writeln(context.l10n.messageSectorAB(
            (i.toString().padLeft(2)).toString(),
            (k.keyA.toUpperCase()).toString(),
            (k.keyB.toUpperCase()).toString()));
      }
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.copiedToClipboard)));
    }
  }

  // ---- Convert file flow ----

  List<DumpFormat> _getAvailableTargets() {
    if (_convertInput == null || _convertInputFormat == null) return [];
    return allowedTargets(_convertInputFormat!);
  }

  Future<void> _pickConvertSource() async {
    final l10n = context.l10n;
    final path = await FileDialogService.pickSingleFilePath(
      desktopTypeGroups: const [
        fs.XTypeGroup(
          label: 'PM3 dump/key',
          extensions: ['eml', 'bin', 'json', 'dump', 'dic', 'txt'],
        ),
      ],
    );
    if (path == null || !mounted) return;
    setState(() {
      _convertInput = path;
      _convertInputFormat = path.split('.').last.toLowerCase();
      _convertTarget = null;
      _convertStatus = null;
    });

    // Also try to extract keys for display
    try {
      final (keys, summary) =
          await extractKeysFromFile(path, localizations: l10n);
      if (!mounted) return;
      setState(() {
        _extractedKeys = keys;
        _keySummary = summary;
      });
    } catch (_) {
      // Not a valid key source — that's fine
    }
  }

  Future<void> _doConvert() async {
    if (_convertInput == null || _convertTarget == null) return;
    final l10n = context.l10n;
    setState(() {
      _converting = true;
      _convertStatus = null;
    });

    try {
      // Suggest output filename
      final baseName =
          _convertInput!.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final defaultName = '$baseName.${_convertTarget!.ext}';

      final savePath = await FileDialogService.pickSaveFilePath(
        dialogTitle: l10n.messageSaveConvertedFile,
        suggestedName: defaultName,
      );
      if (!mounted) return;
      if (savePath == null) {
        setState(() => _converting = false);
        return;
      }

      final result = await convertDumpFile(
        localizations: l10n,
        inputPath: _convertInput!,
        outputPath: savePath,
        targetFormat: _convertTarget!,
      );
      if (!mounted) return;

      setState(() {
        _converting = false;
        if (result.success) {
          _convertStatus = context.l10n.messageConversionSuccessfulOutput(
              (result.outputPath).toString(),
              (result.keySummary ?? '').toString());
        } else {
          _convertStatus = '❌ ${result.error}';
        }
      });
    } catch (e) {
      setState(() {
        _converting = false;
        _convertStatus = context.l10n.messageConversionError((e).toString());
      });
    }
  }

  // ======================================================================
  //  初始化编辑控制器
  // ======================================================================
  void _initEditControllers() {
    // Clean up old controllers
    for (final c in _blockControllers.values) {
      c.dispose();
    }
    for (final c in _keyAControllers.values) {
      c.dispose();
    }
    for (final c in _keyBControllers.values) {
      c.dispose();
    }
    _blockControllers.clear();
    _keyAControllers.clear();
    _keyBControllers.clear();

    if (_card == null) return;

    // Create block data controllers
    for (var i = 0; i < _card!.blocks.length; i++) {
      _blockControllers[i] = TextEditingController(text: _card!.blocks[i]);
    }

    // Create key controllers
    for (var s = 0; s < _card!.sectorKeys.length; s++) {
      _keyAControllers[s] =
          TextEditingController(text: _card!.sectorKeys[s].keyA.toUpperCase());
      _keyBControllers[s] =
          TextEditingController(text: _card!.sectorKeys[s].keyB.toUpperCase());
    }
  }

  /// 应用编辑：将控制器中的值写回 _card 模型
  bool _applyEdits() {
    if (_card == null) return false;
    final blocks = <String>[];
    final keys = <SectorKey>[];
    String normalize(String value, int length) {
      final text = value.replaceAll(RegExp(r'\s'), '').toUpperCase();
      if (text.length != length || !RegExp(r'^[0-9A-F]+$').hasMatch(text)) {
        throw FormatException(
            context.l10n.messageEnterHexDigits((length).toString()));
      }
      return text;
    }

    try {
      for (var b = 0; b < _card!.blocks.length; b++) {
        blocks.add(normalize(_blockControllers[b]!.text, 32));
      }
      for (var s = 0; s < _card!.sectorKeys.length; s++) {
        keys.add(SectorKey(
          keyA: normalize(_keyAControllers[s]!.text, 12),
          keyB: normalize(_keyBControllers[s]!.text, 12),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(context.l10n.messageChangesNotApplied((e).toString()))));
      return false;
    }
    _card!.blocks = blocks;
    _card!.sectorKeys = keys;
    // Invalidate analysis derived from the previous bytes.
    _dumpResult = DumpResult(card: _card!, format: _format);
    setState(() {});
    context.read<AppState>().updateCard(_card!);
    return true;
  }

  // ======================================================================
  //  密钥编辑视图
  // ======================================================================
  Widget _buildKeyEditorView() {
    if (_card == null) return Center(child: Text(context.l10n.messageNoData));

    return Row(
      children: [
        // 左侧：密钥编辑表
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 操作栏
                Row(children: [
                  Text(context.l10n.messageKeyEditor,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _applyEdits,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(context.l10n.messageApplyChanges),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      // 全部设为默认密钥
                      for (var s = 0; s < _card!.sectorKeys.length; s++) {
                        _keyAControllers[s]?.text = 'FFFFFFFFFFFF';
                        _keyBControllers[s]?.text = 'FFFFFFFFFFFF';
                      }
                    },
                    icon: const Icon(Icons.restore, size: 16),
                    label: Text(context.l10n.messageAllDefaults),
                  ),
                ]),
                const SizedBox(height: 12),

                // 密钥编辑表格
                Table(
                  border: TableBorder.all(
                      color: Colors.grey.withValues(alpha: 0.3)),
                  columnWidths: const {
                    0: FixedColumnWidth(55),
                    1: FlexColumnWidth(),
                    2: FlexColumnWidth(),
                  },
                  children: [
                    TableRow(
                        decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
                        children: [
                          Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(context.l10n.messageSector2,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Key A',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Key B',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                        ]),
                    for (var s = 0; s < _card!.sectorKeys.length; s++)
                      TableRow(children: [
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('$s',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12))),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: SizedBox(
                            height: 30,
                            child: TextField(
                              controller: _keyAControllers[s],
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.greenAccent),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                isDense: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9a-fA-F]')),
                                LengthLimitingTextInputFormatter(12),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: SizedBox(
                            height: 30,
                            child: TextField(
                              controller: _keyBControllers[s],
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.cyanAccent),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                isDense: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9a-fA-F]')),
                                LengthLimitingTextInputFormatter(12),
                              ],
                            ),
                          ),
                        ),
                      ]),
                  ],
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // 右侧：块数据编辑
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Text(context.l10n.messageBlockDataEditor,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(context.l10n.messageSector((_selectedSector).toString()),
                      style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ]),
              ),
              // 扇区选择器
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _card!.cardType.sectorCount,
                  itemBuilder: (context, index) {
                    final sel = index == _selectedSector;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text('$index',
                            style: const TextStyle(fontSize: 11)),
                        selected: sel,
                        onSelected: (_) =>
                            setState(() => _selectedSector = index),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 8),
              // 块编辑器
              Expanded(
                child: _buildBlockEditor(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlockEditor() {
    if (_card == null) return const SizedBox();
    final ct = _card!.cardType;
    final sector = _selectedSector;
    final firstBlock = ct.sectorFirstBlock[sector];
    final blockCount = ct.blocksPerSector[sector];
    final trailerIdx = ct.trailerBlock(sector);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: blockCount,
      itemBuilder: (context, i) {
        final block = firstBlock + i;
        final isTrailer = block == trailerIdx;
        final isBlock0 = block == 0 && sector == 0;

        String label = context.l10n.messageData2;
        Color labelColor = Colors.grey;
        if (isBlock0) {
          label = context.l10n.messageManufacturer;
          labelColor = Colors.blue;
        } else if (isTrailer) {
          label = context.l10n.messageTrailer;
          labelColor = Colors.orange;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isTrailer
                ? Colors.orange.withValues(alpha: 0.05)
                : isBlock0
                    ? Colors.blue.withValues(alpha: 0.05)
                    : Colors.transparent,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('B$block',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    Text(label,
                        style: TextStyle(fontSize: 10, color: labelColor)),
                  ],
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _blockControllers[block],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isTrailer
                          ? Colors.orangeAccent
                          : isBlock0
                              ? Colors.lightBlueAccent
                              : null,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      isDense: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================================================================
  //  回写/清空 (CUID) 视图
  // ======================================================================
  Widget _buildWriteBackView() {
    if (_card == null) {
      return Center(child: Text(context.l10n.messageOpenADumpFileFirst));
    }
    final appState = context.watch<AppState>();
    final isConnected = appState.isConnected;
    final progress = appState.writeProgress;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- 说明卡片 ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(context.l10n.messageCuidCardWritingAndClearing,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                context.l10n.messageCuidGen2CardsHaveNoBackdoorCommands,
                style: TextStyle(fontSize: 13),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ---- 连接状态 ----
        if (!isConnected)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.warning, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(context.l10n.messageConnectYourPm3DeviceFirst,
                  style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ]),
          ),
        if (!isConnected) const SizedBox(height: 16),

        // ---- 写入选项 ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.messageWriteOptions,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(children: [
                  Text(context.l10n.messageAuthenticationKeyType),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'A', label: Text('Key A')),
                      ButtonSegment(value: 'B', label: Text('Key B')),
                    ],
                    selected: {_writeKeyType},
                    onSelectionChanged: (v) =>
                        setState(() => _writeKeyType = v.first),
                  ),
                ]),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text(context.l10n.messageSkipBlock0ManufacturerBlock,
                      style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                      context.l10n.messageBlock0CannotBeWrittenUnlessThis,
                      style: TextStyle(fontSize: 11)),
                  value: _skipBlock0,
                  onChanged: (v) => setState(() => _skipBlock0 = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: Text(context.l10n.messageWriteTrailersKeysAccessBits,
                      style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                      context.l10n.messageWriteTheDumpTrailerDataToThe,
                      style: TextStyle(fontSize: 11)),
                  value: _writeTrailers,
                  onChanged: (v) => setState(() => _writeTrailers = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- 密钥概览 (来自 Dump) ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.messageDumpKeysForAuthentication,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: _buildCompactKeyTable(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- 操作按钮 ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.messageSmartWrite,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  context.l10n.messageSelectTheBestWritePathForThe,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<_QuickWriteMode>(
                  initialValue: _quickWriteMode,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: context.l10n.messageTargetCardTypeMode,
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: _QuickWriteMode.auto,
                        child: Text(context.l10n.messageAutoDefault,
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.uid,
                        child: Text(context.l10n.messageStandardUidCard,
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.cuid,
                        child: Text('CUID / Gen2',
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.fuid,
                        child: Text(context.l10n.messageFuidUidCanBeChangedOnce,
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.gen1a,
                        child: Text(context.l10n.messageGen1aBackdoorCard,
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.gen3,
                        child: Text(context.l10n.messageGen3MagicCard,
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.gen4,
                        child:
                            Text('Gen4 GTU', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _quickWriteMode = v);
                  },
                ),
                if (_quickWriteMode == _QuickWriteMode.gen4) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _gen4Pwd,
                    decoration: InputDecoration(
                      labelText: context.l10n.messageGen4PasswordOptional,
                      hintText: context.l10n.message8HexDigitsEG00000000,
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => _gen4Pwd = v.trim(),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isConnected
                        ? () => _executeQuickWriteBack(appState)
                        : null,
                    icon: const Icon(Icons.flash_on, size: 18),
                    label: Text(context.l10n.messageSmartWrite2,
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(children: [
          // CUID 逐块清空
          Expanded(
            child: Tooltip(
              message: context.l10n.messageAuthenticateWithTheDumpKeysAndZero,
              child: ElevatedButton.icon(
                onPressed:
                    isConnected ? () => _showCuidClearDialog(appState) : null,
                icon: const Icon(Icons.delete_sweep),
                label: Text(context.l10n.messageClearEntireCuidCard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // CUID 逐块回写
          Expanded(
            child: Tooltip(
              message: context.l10n.messageAuthenticateWithTheTargetCardKeysAnd,
              child: ElevatedButton.icon(
                onPressed:
                    isConnected ? () => _showCuidWriteDialog(appState) : null,
                icon: const Icon(Icons.upload),
                label: Text(context.l10n.messageWriteEntireCuidCard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // 单扇区回写 + Gen1A restore
        Row(children: [
          Expanded(
            child: Tooltip(
              message: context.l10n
                  .messageWriteOnlySelectedSectorAuthenticateWithThe(
                      (_selectedSector).toString()),
              child: OutlinedButton.icon(
                onPressed:
                    isConnected ? () => _showSectorWriteDialog(appState) : null,
                icon: const Icon(Icons.edit_note),
                label: Text(context.l10n
                    .messageWriteSector((_selectedSector).toString())),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // hf mf restore (Gen1A 后门回写)
          Expanded(
            child: Tooltip(
              message: context.l10n.messageRestoreTheEntireCardUsingThePm3,
              child: OutlinedButton.icon(
                onPressed: isConnected
                    ? () {
                        final sz =
                            Pm3Commands.cardSizeFlag(_card!.cardType.label);
                        appState.sendCommand(Pm3Commands.hfMfRestore(sz));
                      }
                    : null,
                icon: const Icon(Icons.restore),
                label: Text(context.l10n.messageGen1aBackdoorRestore),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ---- 进度显示 ----
        if (progress != null && progress.total > 0) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(context.l10n.messageWriteProgress,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const Spacer(),
                    if (progress.isRunning)
                      TextButton.icon(
                        onPressed: () => appState.cancelWriteSequence(),
                        icon: const Icon(Icons.cancel, size: 16),
                        label: Text(context.l10n.messageCancel),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress.progress,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${progress.completed} / ${progress.total}  '
                    '(✅ ${progress.succeeded}  ❌ ${progress.failed})',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                  Text(progress.localizedStatus(context.l10n),
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  const SizedBox(height: 8),
                  // 逐块结果列表
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: progress.results.length,
                      itemBuilder: (context, index) {
                        final r = progress.results[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(children: [
                            Icon(
                              r.success ? Icons.check_circle : Icons.cancel,
                              size: 14,
                              color: r.success
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                                context.l10n.messageBlock2(
                                    (r.block.toString().padLeft(3)).toString()),
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(r.localizedMessage(context.l10n),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: r.success
                                        ? Colors.greenAccent
                                        : Colors.redAccent)),
                          ]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        // ---- 格式转换 (折叠到这里) ----
        ExpansionTile(
          title: Text(context.l10n.messageFormatConversionAndKeyExtraction,
              style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: _buildConverterView(),
            ),
          ],
        ),
      ]),
    );
  }

  Future<String> _prepareTempDumpBin(AppState appState) async {
    if (!_applyEdits()) {
      throw FormatException(context.l10n.messageEditedDataIsIncomplete);
    }
    final file = File(
      '${Directory.systemTemp.path}/pm3gui-quick-write-${DateTime.now().millisecondsSinceEpoch}.bin',
    );
    await file.writeAsBytes(exportToBin(_card!), flush: true);
    appState.setPreferredMfDumpFile(file.path);
    return file.path;
  }

  Future<void> _executeQuickWriteBack(AppState appState) async {
    if (_card == null) return;

    switch (_quickWriteMode) {
      case _QuickWriteMode.auto:
      case _QuickWriteMode.cuid:
        await _executeCuidWrite(appState);
        return;

      case _QuickWriteMode.uid:
        final old = _skipBlock0;
        setState(() => _skipBlock0 = true);
        try {
          await _executeCuidWrite(appState);
        } finally {
          if (mounted) setState(() => _skipBlock0 = old);
        }
        return;

      case _QuickWriteMode.fuid:
      case _QuickWriteMode.gen3:
        final uid =
            _card!.uid.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
        if (uid.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(context.l10n.messageNoValidUidFoundCannotWriteUid)));
          }
          return;
        }
        await appState.sendCommand(HfMfCmd.gen3uid(uid));
        final old = _skipBlock0;
        setState(() => _skipBlock0 = true);
        try {
          await _executeCuidWrite(appState);
        } finally {
          if (mounted) setState(() => _skipBlock0 = old);
        }
        return;

      case _QuickWriteMode.gen1a:
        final sz = Pm3Commands.cardSizeFlag(_card!.cardType.label);
        final dumpPath = await _prepareTempDumpBin(appState);
        await appState.sendCommand(
          Pm3Commands.hfMfRestore(
            sz,
            keyFile: appState.preferredMfKeyFile,
            dumpFile: dumpPath,
          ),
        );
        return;

      case _QuickWriteMode.gen4:
        final dumpPath = await _prepareTempDumpBin(appState);
        await appState.sendCommand(
          HfMfCmd.gload(
            dumpPath,
            pwd: _gen4Pwd.isNotEmpty ? _gen4Pwd : null,
          ),
        );
        return;
    }
  }

  // 简洁的密钥显示表
  Widget _buildCompactKeyTable() {
    if (_card == null) return const SizedBox();
    final keys = _card!.sectorKeys;
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FixedColumnWidth(40),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        const TableRow(
            decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
            children: [
              Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('S',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
              Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('Key A',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
              Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('Key B',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
            ]),
        for (var i = 0; i < keys.length; i++)
          TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(4),
                child: Text('$i',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11))),
            Padding(
                padding: const EdgeInsets.all(4),
                child: Text(keys[i].keyA.toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: _isKnownDefault(keys[i].keyA)
                            ? Colors.orangeAccent
                            : Colors.greenAccent))),
            Padding(
                padding: const EdgeInsets.all(4),
                child: Text(keys[i].keyB.toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: _isKnownDefault(keys[i].keyB)
                            ? Colors.orangeAccent
                            : Colors.cyanAccent))),
          ]),
      ],
    );
  }

  // ======================================================================
  //  CUID 清空对话框
  // ======================================================================
  void _showCuidClearDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.messageClearCuidBlockByBlock),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              context.l10n.messageAuthenticateTheTargetCardWithTheDump,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.messageBlocksToClear(
                  (_card!.cardType.blockCount).toString(),
                  (_skipBlock0
                          ? context.l10n.messageSkipBlock0
                          : context.l10n.messageIncludeBlock0)
                      .toString()),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.messageCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeCuidClear(appState);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(context.l10n.messageStartClearing,
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  CUID 回写对话框
  // ======================================================================
  void _showCuidWriteDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.messageWriteCuidBlockByBlock),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              context.l10n.messageAuthenticateTheTargetCardWithTheDump2,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.messageBlocksToWrite(
                  (_card!.cardType.blockCount).toString(),
                  (_skipBlock0
                          ? context.l10n.messageSkipBlock0
                          : context.l10n.messageIncludeBlock0)
                      .toString(),
                  (_writeTrailers
                          ? context.l10n.messageIncludeTrailers
                          : context.l10n.messageSkipTrailers)
                      .toString()),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.messageCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeCuidWrite(appState);
            },
            child: Text(context.l10n.messageStartWriting),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  单扇区回写对话框
  // ======================================================================
  void _showSectorWriteDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(context.l10n.messageWriteSector((_selectedSector).toString())),
        content: Text(
          context.l10n.messageAuthenticateWithTheDumpKeysThenWrite(
              (_selectedSector).toString(),
              (_writeTrailers
                      ? context.l10n.messageIncludeTrailers2
                      : context.l10n.messageExcludeTrailers)
                  .toString(),
              (_writeKeyType).toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.messageCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeSectorWrite(appState, _selectedSector);
            },
            child: Text(context.l10n.messageStartWriting),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  执行 CUID 逐块清空
  // ======================================================================
  Future<void> _executeCuidClear(AppState appState) async {
    if (_card == null) return;
    if (!_applyEdits()) return; // 确保最新的密钥

    final commands = <(int, String)>[];
    final ct = _card!.cardType;
    final defaultTrailer = Pm3Commands.defaultTrailerData();

    for (var block = 0; block < ct.blockCount; block++) {
      if (_skipBlock0 && block == 0) continue;

      final sector = _card!.blockToSector(block);
      final key = _writeKeyType == 'A'
          ? _card!.sectorKeys[sector].keyA
          : _card!.sectorKeys[sector].keyB;

      if (_card!.isTrailerBlock(block)) {
        // 尾块写入默认值
        commands.add((
          block,
          Pm3Commands.hfMfCuidWriteBlock(
              block, _writeKeyType, key, defaultTrailer)
        ));
      } else {
        // 数据块写入全 0
        commands.add(
            (block, Pm3Commands.hfMfCuidClearBlock(block, _writeKeyType, key)));
      }
    }

    await appState.sendCommandSequence(commands);
  }

  // ======================================================================
  //  执行 CUID 逐块回写
  // ======================================================================
  Future<void> _executeCuidWrite(AppState appState) async {
    if (_card == null) return;
    if (!_applyEdits()) return; // 确保最新数据

    final commands = <(int, String)>[];
    final ct = _card!.cardType;

    for (var block = 0; block < ct.blockCount; block++) {
      if (_skipBlock0 && block == 0) continue;

      final isTrailer = _card!.isTrailerBlock(block);
      if (isTrailer && !_writeTrailers) continue;

      final sector = _card!.blockToSector(block);
      final key = _writeKeyType == 'A'
          ? _card!.sectorKeys[sector].keyA
          : _card!.sectorKeys[sector].keyB;
      final data = _card!.blocks[block];

      commands.add((
        block,
        Pm3Commands.hfMfCuidWriteBlock(block, _writeKeyType, key, data)
      ));
    }

    await appState.sendCommandSequence(commands);
  }

  // ======================================================================
  //  执行单扇区回写
  // ======================================================================
  Future<void> _executeSectorWrite(AppState appState, int sector) async {
    if (_card == null) return;
    if (!_applyEdits()) return;

    final commands = <(int, String)>[];
    final ct = _card!.cardType;
    final firstBlock = ct.sectorFirstBlock[sector];
    final blockCount = ct.blocksPerSector[sector];

    for (var i = 0; i < blockCount; i++) {
      final block = firstBlock + i;
      if (_skipBlock0 && block == 0) continue;

      final isTrailer = _card!.isTrailerBlock(block);
      if (isTrailer && !_writeTrailers) continue;

      final key = _writeKeyType == 'A'
          ? _card!.sectorKeys[sector].keyA
          : _card!.sectorKeys[sector].keyB;
      final data = _card!.blocks[block];

      commands.add((
        block,
        Pm3Commands.hfMfCuidWriteBlock(block, _writeKeyType, key, data)
      ));
    }

    await appState.sendCommandSequence(commands);
  }
}
