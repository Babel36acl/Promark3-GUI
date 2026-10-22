/// FeliCa operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HfFelicaPage extends StatefulWidget {
  const HfFelicaPage({super.key});

  @override
  State<HfFelicaPage> createState() => _HfFelicaPageState();
}

class _HfFelicaPageState extends State<HfFelicaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sc = '';
  String _bl = '';
  String _blockData = '';
  String _rawHex = '';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildInfoTab(),
        _buildReadWriteTab(),
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
              subtitle: context.l10n.messageReadAFelicaCard,
              icon: Icons.nfc,
              onTap: () => _execute(HfFelicaCmd.reader())),
          ActionCard(
              title: context.l10n.messageTagInformation,
              subtitle: context.l10n.messageGetFelicaDetails,
              icon: Icons.info_outline,
              onTap: () => _execute(HfFelicaCmd.info())),
          ActionCard(
              title: context.l10n.messageDump,
              subtitle: context.l10n.messageDumpCardData,
              icon: Icons.download,
              onTap: () => _execute(HfFelicaCmd.dump())),
          ActionCard(
              title: context.l10n.messageLiteDump,
              subtitle: context.l10n.messageDumpFelicaLite,
              icon: Icons.download_for_offline,
              onTap: () => _execute(HfFelicaCmd.litedump())),
          ActionCard(
              title: context.l10n.messageSniff,
              subtitle: context.l10n.messageCaptureFelicaCommunication,
              icon: Icons.hearing,
              onTap: () => _execute(HfFelicaCmd.sniff())),
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
      sideWidth: 340,
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
                    Row(children: [
                      Expanded(
                          child: HexInputField(
                              label: context.l10n.messageScServiceCode,
                              onChanged: (v) => _sc = v)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: HexInputField(
                              label: context.l10n.messageBlBlockNumber,
                              onChanged: (v) => _bl = v)),
                    ]),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _sc.isNotEmpty && _bl.isNotEmpty
                            ? () => _execute(HfFelicaCmd.rdbl(_sc, _bl))
                            : null,
                        icon: const Icon(Icons.visibility, size: 18),
                        label: Text(context.l10n.messageReadBlock)),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: context.l10n.messageWriteDataHex,
                        onChanged: (v) => _blockData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _blockData.isNotEmpty &&
                                _sc.isNotEmpty &&
                                _bl.isNotEmpty
                            ? () =>
                                _execute(HfFelicaCmd.wrbl(_sc, _bl, _blockData))
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
                            ? () => _execute(HfFelicaCmd.raw(_rawHex))
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
}
