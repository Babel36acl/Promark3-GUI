/// LF HID Prox operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class LfHidPage extends StatefulWidget {
  const LfHidPage({super.key});

  @override
  State<LfHidPage> createState() => _LfHidPageState();
}

class _LfHidPageState extends State<LfHidPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _cardData = '';
  String _fc = '';

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
        Tab(text: context.l10n.messageRead),
        Tab(text: context.l10n.messageCloneSimulate2),
        Tab(text: context.l10n.hidReaderBruteForceTab),
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildReadTab(),
        _buildCloneSimTab(),
        _buildBruteForceTab(),
      ])),
    ]);
  }

  Widget _buildReadTab() {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messageReadHidCard,
              subtitle: context.l10n.messageReadAHidProxCard,
              icon: Icons.nfc,
              onTap: () => _execute(LfHidCmd.reader())),
          ActionCard(
              title: context.l10n.messageDemodulateSignal,
              subtitle: context.l10n.messageDemodulateTheHidLfSignal,
              icon: Icons.radio,
              onTap: () => _execute(LfHidCmd.demod())),
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

  Widget _buildCloneSimTab() {
    return SplitPageLayout(
      sideWidth: 340,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageCloneSimulate,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: context.l10n.messageWiegandData,
                        hintText: context.l10n.messageForExample2006ec0c86,
                        prefixIcon: Icon(Icons.credit_card, size: 18),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9a-fA-F]'))
                      ],
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      onChanged: (v) => _cardData = v,
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: _cardData.isNotEmpty
                              ? () => _execute(LfHidCmd.clone(_cardData))
                              : null,
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(context.l10n.messageCloneToT55xx)),
                      OutlinedButton.icon(
                          onPressed: _cardData.isNotEmpty
                              ? () => _execute(LfHidCmd.sim(_cardData))
                              : null,
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
              })),
    );
  }

  Widget _buildBruteForceTab() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.hidReaderBruteForceTitle,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: context.l10n.messageFcOptional,
                        hintText: context.l10n.messageLeaveBlankToTryAllValues,
                        prefixIcon: Icon(Icons.numbers, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => _fc = v,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                        onPressed: () => _execute(
                            LfHidCmd.brute(fc: _fc.isEmpty ? null : _fc)),
                        icon: const Icon(Icons.bolt, size: 18),
                        label: Text(context.l10n.hidStartBruteForce)),
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
