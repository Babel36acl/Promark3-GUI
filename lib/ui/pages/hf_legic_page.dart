/// Legic operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HfLegicPage extends StatefulWidget {
  const HfLegicPage({super.key});

  @override
  State<HfLegicPage> createState() => _HfLegicPageState();
}

class _HfLegicPageState extends State<HfLegicPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _offset = 0;
  int _length = 16;
  String _writeData = '';

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
              title: context.l10n.messageTagInformation,
              subtitle: context.l10n.messageReadALegicTag,
              icon: Icons.info_outline,
              onTap: () => _execute(HfLegicCmd.info())),
          ActionCard(
              title: context.l10n.messageDump,
              subtitle: context.l10n.messageDumpAllData,
              icon: Icons.download,
              onTap: () => _execute(HfLegicCmd.dump())),
          ActionCard(
              title: context.l10n.messageErase,
              subtitle: context.l10n.messageClearCardData,
              icon: Icons.delete_forever,
              onTap: () => _confirmThenExecute(
                  context.l10n.messageConfirmErase,
                  context.l10n.messageThisOperationCannotBeUndone,
                  HfLegicCmd.wipe())),
          ActionCard(
              title: context.l10n.messageSimulate,
              subtitle: context.l10n.messageSimulateALegicTag,
              icon: Icons.play_arrow,
              onTap: () => _execute(HfLegicCmd.sim())),
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
                    Text(context.l10n.messageReadWriteOperations,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.messageOffset),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (v) => _offset = int.tryParse(v) ?? 0,
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.messageLength),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        initialValue: '16',
                        onChanged: (v) => _length = int.tryParse(v) ?? 16,
                      )),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          onPressed: () =>
                              _execute(HfLegicCmd.rdbl(_offset, _length)),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: Text(context.l10n.messageRead)),
                    ),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: context.l10n.messageWriteDataHex,
                        onChanged: (v) => _writeData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _writeData.isNotEmpty
                            ? () =>
                                _execute(HfLegicCmd.wrbl(_offset, _writeData))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(context.l10n.messageWrite)),
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

  void _confirmThenExecute(String title, String msg, String cmd) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(title),
              content: Text(msg),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.messageCancel)),
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _execute(cmd);
                    },
                    child: Text(context.l10n.messageConfirm)),
              ],
            ));
  }
}
