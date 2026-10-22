/// iCLASS / Picopass operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HfIclassPage extends StatefulWidget {
  const HfIclassPage({super.key});

  @override
  State<HfIclassPage> createState() => _HfIclassPageState();
}

class _HfIclassPageState extends State<HfIclassPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _blockNumber = 0;
  String _key = '';
  String _blockData = '';
  String _emuFile = '';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _execute(String cmd) async {
    if (!ensurePm3Ready(context)) return;
    setState(() {
      _lastCmd = cmd;
      _isLoading = true;
      _result = '';
    });
    final buf = StringBuffer();
    _sub?.cancel();
    _sub = context.read<AppState>().pm3PageOutput.listen((line) {
      if (!line.startsWith('[pm3]')) {
        buf.writeln(line);
        if (mounted) setState(() => _result = buf.toString());
      }
    });
    await context.read<AppState>().sendCommand(cmd);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(controller: _tabController, tabs: [
          Tab(text: context.l10n.messageInformation),
          Tab(text: context.l10n.messageReadWrite),
          Tab(text: context.l10n.messageKeyRecovery),
          Tab(text: context.l10n.messageEmulator),
        ]),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            _buildInfoTab(),
            _buildReadWriteTab(),
            _buildCrackTab(),
            _buildEmulatorTab(),
          ]),
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messageGetInformation,
              subtitle: context.l10n.messageReadAnIclassTag,
              icon: Icons.info_outline,
              onTap: () => _execute(HfIclassCmd.info())),
          ActionCard(
              title: context.l10n.messageReadCard,
              subtitle: context.l10n.messageReaderMode,
              icon: Icons.nfc,
              onTap: () => _execute(HfIclassCmd.reader())),
          ActionCard(
              title: context.l10n.messageDumpCard,
              subtitle: context.l10n.messageDumpAllBlocksToAFile,
              icon: Icons.download,
              onTap: () =>
                  _execute(HfIclassCmd.dump(key: _key.isEmpty ? null : _key))),
        ],
      ),
      main: ResultDisplay(
        command: _lastCmd,
        result: _result,
        isLoading: _isLoading,
        onClear: () => setState(() {
          _result = '';
          _lastCmd = '';
        }),
      ),
    );
  }

  Widget _buildReadWriteTab() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageBlockOperations,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: context.l10n.messageKey8ByteHex,
                        byteLength: 8,
                        onChanged: (v) => _key = v,
                        prefixIcon: Icons.vpn_key),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                          labelText: context.l10n.messageBlockNumber),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => _blockNumber = int.tryParse(v) ?? 0,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _execute(HfIclassCmd.rdbl(_blockNumber,
                            key: _key.isEmpty ? null : _key)),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: Text(context.l10n.messageReadBlock),
                      ),
                    ),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: context.l10n.messageWriteData8ByteHex,
                        byteLength: 8,
                        onChanged: (v) => _blockData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _blockData.length == 16
                          ? () => _execute(HfIclassCmd.wrbl(
                              _blockNumber, _blockData,
                              key: _key.isEmpty ? null : _key))
                          : null,
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(context.l10n.messageWriteBlock),
                    ),
                  ],
                ))),
      ]),
      main: ResultDisplay(
        command: _lastCmd,
        result: _result,
        isLoading: _isLoading,
        onClear: () => setState(() {
          _result = '';
          _lastCmd = '';
        }),
      ),
    );
  }

  Widget _buildCrackTab() {
    return SplitPageLayout(
      sideWidth: 300,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ActionCard(
            title: context.l10n.messageCheckKeys,
            subtitle: context.l10n.messageCheckCommonDefaultKeys,
            icon: Icons.security,
            onTap: () => _execute(HfIclassCmd.chk())),
        ActionCard(
            title: context.l10n.messageLoclassAttack,
            subtitle: context.l10n.messageRecoverIclassKeysOffline,
            icon: Icons.bolt,
            onTap: () => _execute(HfIclassCmd.loclass())),
        ActionCard(
            title: context.l10n.messageSniffCommunication,
            subtitle: context.l10n.messageCaptureCardReaderCommunication,
            icon: Icons.hearing,
            onTap: () => _execute(HfIclassCmd.sniff())),
      ]),
      main: ResultDisplay(
        command: _lastCmd,
        result: _result,
        isLoading: _isLoading,
        onClear: () => setState(() {
          _result = '';
          _lastCmd = '';
        }),
      ),
    );
  }

  Widget _buildEmulatorTab() {
    return SplitPageLayout(
      sideWidth: 340,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageEmulatorOperations,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                          labelText: context.l10n.messageFilePathOptional,
                          hintText:
                              context.l10n.messageLeaveBlankToUseTheDefault,
                          prefixIcon: Icon(Icons.file_open, size: 18)),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      onChanged: (v) => _emuFile = v.trim(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: () => _execute(HfIclassCmd.eload(
                              _emuFile.isEmpty ? 'dump' : _emuFile)),
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(context.l10n.messageLoadIntoEmulator)),
                      OutlinedButton.icon(
                          onPressed: () => _execute(HfIclassCmd.eview()),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: Text(context.l10n.messageView)),
                      ElevatedButton.icon(
                          onPressed: () => _execute(HfIclassCmd.sim()),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(context.l10n.messageSimulate)),
                    ]),
                  ],
                ))),
      ]),
      main: ResultDisplay(
        command: _lastCmd,
        result: _result,
        isLoading: _isLoading,
        onClear: () => setState(() {
          _result = '';
          _lastCmd = '';
        }),
      ),
    );
  }
}
