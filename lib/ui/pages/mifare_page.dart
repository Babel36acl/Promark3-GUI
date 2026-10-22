/// Mifare operations page — read/write/attack Mifare Classic cards.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class MifarePage extends StatefulWidget {
  const MifarePage({super.key});

  @override
  State<MifarePage> createState() => _MifarePageState();
}

class _MifarePageState extends State<MifarePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCardSize = '1K';
  String _keyA = 'FFFFFFFFFFFF';
  int _selectedBlock = 0;
  String _selectedKeyType = 'A';
  String _writeData = '';
  String _quickKeyFile = '';
  String _quickDumpFile = '';
  String _scriptName = '';
  String _lastCmd = '';

  // 命令结果
  String _lastResult = '';
  bool _isExecuting = false;
  StreamSubscription<String>? _outputSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _outputSub?.cancel();
    super.dispose();
  }

  Future<void> _execute(String cmd) async {
    await _executeWithResult(cmd);
  }

  /// 执行命令并捕获结果到 _lastResult
  Future<void> _executeWithResult(String cmd) async {
    final appState = context.read<AppState>();
    if (!ensurePm3Ready(context)) return;

    setState(() {
      _lastCmd = cmd;
      _isExecuting = true;
      _lastResult = '';
    });

    final buffer = StringBuffer();
    _outputSub?.cancel();
    _outputSub = appState.pm3PageOutput.listen((line) {
      // 过滤掉 [pm3] 自身发送的命令回显
      if (!line.startsWith('[pm3]')) {
        buffer.writeln(line);
        if (mounted) setState(() => _lastResult = buffer.toString());
      }
    });

    await appState.sendCommand(cmd);
    if (mounted) setState(() => _isExecuting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Card size selector
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text(context.l10n.messageCardType2,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'MINI', label: Text('Mini')),
                  ButtonSegment(value: '1K', label: Text('1K')),
                  ButtonSegment(value: '2K', label: Text('2K')),
                  ButtonSegment(value: '4K', label: Text('4K')),
                ],
                selected: {_selectedCardSize},
                onSelectionChanged: (v) =>
                    setState(() => _selectedCardSize = v.first),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.messageQuickActions),
            Tab(text: context.l10n.messageKeyRecoveryAttacks),
            Tab(text: context.l10n.messageReadWriteBlocks),
            Tab(text: context.l10n.messageMagicCards),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildQuickActions(),
              _buildKeyAttack(),
              _buildReadWrite(),
              _buildMagicCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final flag = Pm3Commands.cardSizeFlag(_selectedCardSize);
    final appState = context.watch<AppState>();
    final effectiveKey = _quickKeyFile.trim().isNotEmpty
        ? _quickKeyFile.trim()
        : (appState.preferredMfKeyFile ?? '');
    final effectiveDump = _quickDumpFile.trim().isNotEmpty
        ? _quickDumpFile.trim()
        : (appState.preferredMfDumpFile ?? '');
    return SplitPageLayout(
      sideWidth: 360,
      sideScrollable: false,
      side: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageDumpRestoreParametersOptional,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _quickKeyFile,
                      decoration: InputDecoration(
                        labelText: context.l10n.messageKeyFileKeysOptional,
                        hintText: appState.preferredMfKeyFile ??
                            context.l10n.messageLeaveBlankToUseThePm3Default,
                        prefixIcon: const Icon(Icons.vpn_key, size: 18),
                      ),
                      onChanged: (v) => _quickKeyFile = v,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _quickDumpFile,
                      decoration: InputDecoration(
                        labelText: context.l10n.messageDumpFileFileOptional,
                        hintText: appState.preferredMfDumpFile ??
                            context.l10n.messageDumpOutputFileRestoreInputFile,
                        prefixIcon: const Icon(Icons.file_open, size: 18),
                      ),
                      onChanged: (v) => _quickDumpFile = v,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final path =
                                await FileDialogService.pickSingleFilePath(
                              desktopTypeGroups: const [
                                fs.XTypeGroup(
                                    label: 'key',
                                    extensions: ['bin', 'dic', 'txt'])
                              ],
                            );
                            if (path != null) {
                              setState(() => _quickKeyFile = path);
                            }
                          },
                          icon: const Icon(Icons.vpn_key, size: 16),
                          label: Text(context.l10n.messageSelectKeyFile),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final path =
                                await FileDialogService.pickSingleFilePath(
                              desktopTypeGroups: const [
                                fs.XTypeGroup(
                                    label: 'dump',
                                    extensions: ['bin', 'eml', 'json', 'dump'])
                              ],
                            );
                            if (path != null) {
                              setState(() => _quickDumpFile = path);
                            }
                          },
                          icon: const Icon(Icons.file_open, size: 16),
                          label: Text(context.l10n.messageSelectDumpFile),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _quickKeyFile = '';
                            _quickDumpFile = '';
                          }),
                          icon: const Icon(Icons.cleaning_services, size: 16),
                          label: Text(context.l10n.messageClearCustomSettings),
                        ),
                      ],
                    ),
                    if (appState.preferredMfKeyFile != null ||
                        appState.preferredMfDumpFile != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.messageDefaultSourcesKeyDump(
                            (appState.preferredMfKeyFile ?? '-').toString(),
                            (appState.preferredMfDumpFile ?? '-').toString()),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _actionCard(context.l10n.messageDetectCard,
                context.l10n.messageScanHf14aTags, Icons.search, () {
              _execute(Pm3Commands.hf14aSearch());
            }),
            _actionCard(
                context.l10n.messageCardInformation,
                context.l10n.messageGetDetailedCardInformation,
                Icons.info_outline, () {
              _execute(Pm3Commands.hfMfInfo());
            }),
            _actionCard(context.l10n.terminalAutopwn,
                context.l10n.messageAutomaticKeyRecovery, Icons.bolt, () {
              _execute(Pm3Commands.hfMfAutopwn(flag));
            }),
            _actionCard(context.l10n.messageDumpCard,
                context.l10n.messageReadAllSectorsToAFile, Icons.download, () {
              _execute(Pm3Commands.hfMfDump(
                flag,
                keyFile: effectiveKey.isEmpty ? null : effectiveKey,
                dumpFile: effectiveDump.isEmpty ? null : effectiveDump,
              ));
            }),
            _actionCard(
                context.l10n.messageRestoreCard,
                context.l10n.messageWriteTheDumpBackToTheCard,
                Icons.upload, () {
              _execute(Pm3Commands.hfMfRestore(
                flag,
                keyFile: effectiveKey.isEmpty ? null : effectiveKey,
                dumpFile: effectiveDump.isEmpty ? null : effectiveDump,
              ));
            }),
            _actionCard(
                context.l10n.messageSniff2,
                context.l10n.messageCaptureCardCommunication,
                Icons.hearing, () {
              _execute(Pm3Commands.hf14aSniff());
            }),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        context.l10n
                            .messageMoreCardRecoveryDiagnosticsSeeCommandReference,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _execute(HfMfuCmd.cchk()),
                          icon: const Icon(Icons.security, size: 16),
                          label: const Text('MFU CCheck'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _execute(HfMfdesCmd.chk()),
                          icon: const Icon(Icons.lock_open, size: 16),
                          label: const Text('DESFire CHK'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _execute(Hf14bCmd.info()),
                          icon: const Icon(Icons.contactless, size: 16),
                          label: const Text('ISO14443-B INFO'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _execute(Hf14aCmd.cuids(count: 20)),
                          icon: const Icon(Icons.qr_code, size: 16),
                          label: Text(context.l10n.messageCollectCuid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: _scriptName,
                      decoration: InputDecoration(
                        labelText:
                            context.l10n.messagePm3ScriptNameScriptRunName,
                        hintText: context.l10n.messageForExampleMifareMfAutopwn,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => _scriptName = v.trim(),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _execute(ScriptCmd.list()),
                          icon: const Icon(Icons.list, size: 16),
                          label: Text(context.l10n.messageListScripts),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _scriptName.isEmpty
                              ? null
                              : () => _execute(ScriptCmd.run(_scriptName)),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: Text(context.l10n.messageRunScript),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      main: _buildCommandWindow(),
    );
  }

  Widget _buildKeyAttack() {
    final flag = Pm3Commands.cardSizeFlag(_selectedCardSize);
    return SplitPageLayout(
      sideWidth: 320,
      sideScrollable: false,
      side: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Known key input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageKnownKey,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _keyA,
                          decoration: InputDecoration(
                              labelText: context.l10n.messageKeyHex),
                          onChanged: (v) => _keyA = v,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'A', label: Text('A')),
                          ButtonSegment(value: 'B', label: Text('B')),
                        ],
                        selected: {_selectedKeyType},
                        onSelectionChanged: (v) =>
                            setState(() => _selectedKeyType = v.first),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '0',
                          decoration: InputDecoration(
                              labelText: context.l10n.messageBlockNumber),
                          onChanged: (v) =>
                              _selectedBlock = int.tryParse(v) ?? 0,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _actionCard(
                context.l10n.messageCheckKeys,
                context.l10n.messageTryDefaultKeysOnAllSectors,
                Icons.vpn_key, () {
              _execute(Pm3Commands.hfMfCheck(flag));
            }),
            _actionCard(
                context.l10n.messageNestedAttack,
                context.l10n.messageUseAKnownKeyToFindOther,
                Icons.account_tree, () {
              _execute(Pm3Commands.hfMfNested(
                  flag, _selectedBlock, _selectedKeyType, _keyA));
            }),
            _actionCard('Static Nested',
                context.l10n.messageForCardsWithStaticNonces, Icons.repeat, () {
              _execute(Pm3Commands.hfMfStaticNested(
                  flag, _selectedBlock, _selectedKeyType, _keyA));
            }),
            _actionCard('Hardnested', context.l10n.messageAdvancedKeyRecovery,
                Icons.security, () {
              _execute(Pm3Commands.hfMfHardnested(
                  _selectedBlock, _selectedKeyType, _keyA, 0, 'A'));
            }),
            _actionCard('Darkside', context.l10n.messageNoKnownKeyRequired,
                Icons.dark_mode, () {
              _execute(Pm3Commands.hfMfDarkside());
            }),
          ],
        ),
      ),
      main: _buildCommandWindow(),
    );
  }

  Widget _buildReadWrite() {
    return SplitPageLayout(
      sideWidth: 360,
      sideScrollable: false,
      side: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageBlockOperations,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                        initialValue: '0',
                        decoration: InputDecoration(
                            labelText: context.l10n.messageBlockNumber),
                        onChanged: (v) => _selectedBlock = int.tryParse(v) ?? 0,
                        keyboardType: TextInputType.number,
                      )),
                      const SizedBox(width: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'A', label: Text('Key A')),
                          ButtonSegment(value: 'B', label: Text('Key B')),
                        ],
                        selected: {_selectedKeyType},
                        onSelectionChanged: (v) =>
                            setState(() => _selectedKeyType = v.first),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _keyA,
                      decoration: InputDecoration(
                          labelText: context.l10n.messageKeyHex),
                      onChanged: (v) => _keyA = v,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 读取块按钮
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.visibility,
                    color: Theme.of(context).colorScheme.primary),
                title: Text(context.l10n.messageReadBlock),
                subtitle: Text(context.l10n.messageReadDataFromOneBlock,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                trailing: _isExecuting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                onTap: () {
                  _executeWithResult(Pm3Commands.hfMfReadBlock(
                      _selectedBlock, _selectedKeyType, _keyA));
                },
              ),
            ),
            const SizedBox(height: 8),

            // 写入数据
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageWriteData,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: context.l10n.messageData32HexDigits,
                        hintText: context.l10n
                            .messageForExample00000000000000000000000000000000,
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                      onChanged: (v) => _writeData = v,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _writeData.length == 32
                            ? () {
                                _executeWithResult(Pm3Commands.hfMfWriteBlock(
                                    _selectedBlock,
                                    _selectedKeyType,
                                    _keyA,
                                    _writeData));
                              }
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(context.l10n.messageWriteBlock),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      main: _buildCommandWindow(),
    );
  }

  Widget _buildMagicCard() {
    return SplitPageLayout(
      sideWidth: 320,
      sideScrollable: false,
      side: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 36),
                    SizedBox(height: 8),
                    Text(
                      context.l10n.messageMagicCardOperations,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      context.l10n.messageTheseCommandsOnlyApplyToGen1aGen2,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _actionCard(
                context.l10n.messageReadBlock0,
                context.l10n.messageReadManufacturerBlock,
                Icons.visibility, () {
              _execute(Pm3Commands.hfMfMagicGetBlock(0));
            }),
            _actionCard(
                context.l10n.messageEraseCard,
                context.l10n.messageRestoreFactoryDefaults,
                Icons.delete_forever, () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.l10n.messageEraseCard2),
                  content:
                      Text(context.l10n.messageThisWillResetAllBlocksAreYou),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(context.l10n.messageCancel)),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _execute(Pm3Commands.hfMfMagicWipe());
                      },
                      child: Text(context.l10n.messageErase,
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            }),
            _actionCard(context.l10n.messageLoadEmulator,
                context.l10n.messageLoadADumpIntoTheEmulator, Icons.memory, () {
              _execute(Pm3Commands.hfMfEmulatorClear());
            }),
          ],
        ),
      ),
      main: _buildCommandWindow(),
    );
  }

  Widget _buildCommandWindow() {
    return ResultDisplay(
      command: _lastCmd,
      result: _lastResult,
      isLoading: _isExecuting,
      onClear: () => setState(() {
        _lastResult = '';
        _lastCmd = '';
      }),
    );
  }

  Widget _actionCard(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        trailing: const Icon(Icons.play_arrow),
        onTap: onTap,
      ),
    );
  }
}
