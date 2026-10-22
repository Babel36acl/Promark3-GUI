/// ISO 15693 operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class Hf15Page extends StatefulWidget {
  const Hf15Page({super.key});

  @override
  State<Hf15Page> createState() => _Hf15PageState();
}

class _Hf15PageState extends State<Hf15Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _blockNumber = 0;
  String _blockData = '';
  String _uid = '';

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
              subtitle: context.l10n.messageAutomaticallyReadIso15693,
              icon: Icons.nfc,
              onTap: () => _execute(Hf15Cmd.reader())),
          ActionCard(
              title: context.l10n.messageTagInformation,
              subtitle: context.l10n.messageReadBasicTagInformation,
              icon: Icons.info_outline,
              onTap: () => _execute(Hf15Cmd.info())),
          ActionCard(
              title: context.l10n.messageDumpCard,
              subtitle: context.l10n.messageReadAllData,
              icon: Icons.download,
              onTap: () => _execute(Hf15Cmd.dump())),
          ActionCard(
              title: context.l10n.messageEraseCard,
              subtitle: context.l10n.messageClearCardData,
              icon: Icons.delete_forever,
              onTap: () => _confirmThenExecute(
                  context.l10n.messageConfirmErase,
                  context.l10n.messageThisOperationCannotBeUndone,
                  Hf15Cmd.wipe())),
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
                          onPressed: () => _execute(Hf15Cmd.rdbl(_blockNumber)),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: Text(context.l10n.messageReadBlock)),
                    ),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: context.l10n.messageWriteData4ByteHex,
                        byteLength: 4,
                        onChanged: (v) => _blockData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _blockData.length == 8
                            ? () =>
                                _execute(Hf15Cmd.wrbl(_blockNumber, _blockData))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(context.l10n.messageWriteBlock)),
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
      sideWidth: 320,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ActionCard(
            title: context.l10n.messageFindAfi,
            subtitle: context.l10n.messageScanApplicationFamilyIdentifiers,
            icon: Icons.search,
            onTap: () => _execute(Hf15Cmd.findafi())),
        ActionCard(
            title: context.l10n.messageSimulateCard,
            subtitle: context.l10n.messageSimulateAnIso15693Tag,
            icon: Icons.play_arrow,
            onTap: () => _execute(Hf15Cmd.sim())),
        ActionCard(
            title: context.l10n.messageSniffCommunication,
            subtitle: context.l10n.messageCaptureReaderCommunication,
            icon: Icons.hearing,
            onTap: () => _execute(Hf15Cmd.sniff())),
        const Divider(),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageSetUid,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: context.l10n.messageUid8ByteHex,
                        byteLength: 8,
                        onChanged: (v) => _uid = v,
                        prefixIcon: Icons.credit_card),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _uid.length == 16
                            ? () => _execute(Hf15Cmd.csetuid(_uid))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(context.l10n.messageSetUid)),
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
