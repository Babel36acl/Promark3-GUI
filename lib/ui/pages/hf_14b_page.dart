/// ISO 14443-B operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class Hf14bPage extends StatefulWidget {
  const Hf14bPage({super.key});

  @override
  State<Hf14bPage> createState() => _Hf14bPageState();
}

class _Hf14bPageState extends State<Hf14bPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _blockNumber = 0;
  String _blockData = '';
  String _rawHex = '';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    return Column(children: [
      TabBar(controller: _tabController, tabs: [
        Tab(text: context.l10n.messageInformation),
        Tab(text: context.l10n.messageReadWrite),
        Tab(text: context.l10n.navTools),
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildInfoTab(),
        _buildReadWriteTab(),
        _buildToolsTab(),
      ])),
    ]);
  }

  Widget _buildInfoTab() {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messageReader,
              subtitle: context.l10n.messageReadA14443BCard,
              icon: Icons.nfc,
              onTap: () => _execute(Hf14bCmd.reader())),
          ActionCard(
              title: context.l10n.messageTagInformation,
              subtitle: context.l10n.messageReadTagDetails,
              icon: Icons.info_outline,
              onTap: () => _execute(Hf14bCmd.info())),
          ActionCard(
              title: context.l10n.messageSniff,
              subtitle: context.l10n.messageCapture14443BCommunication,
              icon: Icons.hearing,
              onTap: () => _execute(Hf14bCmd.sniff())),
          ActionCard(
              title: context.l10n.messageDump,
              subtitle: context.l10n.messageReadAllData,
              icon: Icons.download,
              onTap: () => _execute(Hf14bCmd.dump())),
          ActionCard(
              title: 'NDEF',
              subtitle: context.l10n.messageReadNdefData,
              icon: Icons.article,
              onTap: () => _execute(Hf14bCmd.ndefRead())),
        ],
      ),
      main: ResultDisplay(
          command: _lastCmd,
          result: _result,
          isLoading: _isLoading,
          onClear: () => setState(() {
                _result = '';
                _lastCmd = '';
              })),
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
                          onPressed: () =>
                              _execute(Hf14bCmd.rdbl(_blockNumber)),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: Text(context.l10n.messageReadBlock)),
                    ),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: context.l10n.messageWriteDataHex,
                        byteLength: 4,
                        onChanged: (v) => _blockData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _blockData.length == 8
                            ? () => _execute(
                                Hf14bCmd.wrbl(_blockNumber, _blockData))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(context.l10n.messageWriteBlock)),
                  ],
                ))),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageRawCommand,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: context.l10n.messageRawHexData,
                        onChanged: (v) => _rawHex = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _rawHex.isNotEmpty
                            ? () => _execute(Hf14bCmd.raw(_rawHex))
                            : null,
                        icon: const Icon(Icons.send, size: 18),
                        label: Text(context.l10n.terminalSend)),
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
              })),
    );
  }

  Widget _buildToolsTab() {
    return SplitPageLayout(
      sideWidth: 280,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ActionCard(
            title: context.l10n.messageSimulateCard,
            subtitle: context.l10n.messageSimulateA14443BTag,
            icon: Icons.play_arrow,
            onTap: () => _execute(Hf14bCmd.sim())),
      ]),
      main: ResultDisplay(
          command: _lastCmd,
          result: _result,
          isLoading: _isLoading,
          onClear: () => setState(() {
                _result = '';
                _lastCmd = '';
              })),
    );
  }
}
