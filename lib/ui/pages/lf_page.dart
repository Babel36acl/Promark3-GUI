/// LF (Low Frequency) operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class LfPage extends StatefulWidget {
  const LfPage({super.key});

  @override
  State<LfPage> createState() => _LfPageState();
}

class _LfPageState extends State<LfPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _em410xId = '';

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
    final appState = context.read<AppState>();
    if (!ensurePm3Ready(context)) return;

    setState(() {
      _lastCmd = cmd;
      _isLoading = true;
      _result = '';
    });

    final buf = StringBuffer();
    _sub?.cancel();
    _sub = appState.pm3PageOutput.listen((line) {
      if (!line.startsWith('[pm3]')) {
        buf.writeln(line);
        if (mounted) setState(() => _result = buf.toString());
      }
    });

    await appState.sendCommand(cmd);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.messageGeneral),
            Tab(text: 'EM4x05'),
            Tab(text: 'T55xx'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGeneral(),
              _buildEm4x(),
              _buildT55xx(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneral() {
    return SplitPageLayout(
      sideWidth: 300,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionCard(
              context.l10n.terminalLfSearch,
              context.l10n.messageAutomaticallyDetectLowFrequencyTags,
              Icons.search, () {
            _execute(Pm3Commands.lfSearch());
          }),
          _actionCard(
              context.l10n.terminalLfRead,
              context.l10n.messageReadTheRawLowFrequencySignal,
              Icons.sensors, () {
            _execute(Pm3Commands.lfRead());
          }),
          _actionCard(
              context.l10n.messageLfSniff,
              context.l10n.messageCaptureLowFrequencyCommunication,
              Icons.hearing, () {
            _execute(Pm3Commands.lfSniff());
          }),
          _actionCard(context.l10n.antennaTune,
              context.l10n.messageCheckAntennaTuning, Icons.tune, () {
            _execute(Pm3Commands.lfTune());
          }),
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

  Widget _buildEm4x() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionCard(context.l10n.messageReadEm410x,
              context.l10n.messageReadTheEm4100TagId, Icons.nfc, () {
            _execute(Pm3Commands.lfEm410xRead());
          }),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.messageCloneEm410x,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: context.l10n.messageTagId10HexDigits,
                      hintText: context.l10n.messageForExample0102030405,
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                    onChanged: (v) => _em410xId = v,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_em410xId.length == 10) {
                        _execute(Pm3Commands.lfEm410xClone(_em410xId));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(context
                                  .l10n.messageIdMustContain10HexDigits)),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(context.l10n.messageClone),
                  ),
                ],
              ),
            ),
          ),
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

  Widget _buildT55xx() {
    return SplitPageLayout(
      sideWidth: 360,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionCard(
              context.l10n.messageDetect,
              context.l10n.messageDetectT55xxChipConfiguration,
              Icons.memory, () {
            _execute(Pm3Commands.lfT55xxDetect());
          }),
          _actionCard(
              context.l10n.messageInformation,
              context.l10n.messageShowT55xxConfiguration,
              Icons.info_outline, () {
            _execute(Pm3Commands.lfT55xxInfo());
          }),
          _actionCard(context.l10n.messageDump,
              context.l10n.messageDumpAllT55xxBlocks, Icons.download, () {
            _execute(Pm3Commands.lfT55xxDump());
          }),
          const Divider(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.messageBlockOperations,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (var block = 0; block < 8; block++)
                    ListTile(
                      dense: true,
                      title: Text(
                          context.l10n.messageBlock2((block).toString()),
                          style: const TextStyle(fontFamily: 'monospace')),
                      trailing: Wrap(
                        runSpacing: 8,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 20),
                            onPressed: () =>
                                _execute(Pm3Commands.lfT55xxReadBlock(block)),
                            tooltip: context.l10n.messageRead,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
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
