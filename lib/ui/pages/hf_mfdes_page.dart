/// Mifare DESFire operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HfMfdesPage extends StatefulWidget {
  const HfMfdesPage({super.key});

  @override
  State<HfMfdesPage> createState() => _HfMfdesPageState();
}

class _HfMfdesPageState extends State<HfMfdesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _aid = '';
  String _fid = '';
  String _key = '';
  int _keyNumber = 0;
  String _algorithm = 'aes';
  String _writeData = '';

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
    return Column(children: [
      TabBar(controller: _tabController, tabs: [
        Tab(text: context.l10n.messageInformation),
        Tab(text: context.l10n.desfireApplicationsTab),
        Tab(text: context.l10n.messageFiles),
        Tab(text: context.l10n.messageManagement),
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildInfoTab(),
        _buildAppTab(),
        _buildFileTab(),
        _buildManageTab(),
      ])),
    ]);
  }

  Widget _buildInfoTab() {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messageDetect,
              subtitle: context.l10n.messageDetectADesfireCard,
              icon: Icons.search,
              onTap: () => _execute(HfMfdesCmd.detect())),
          ActionCard(
              title: context.l10n.messageInformation,
              subtitle: context.l10n.messageReadBasicCardInformation,
              icon: Icons.info_outline,
              onTap: () => _execute(HfMfdesCmd.info())),
          ActionCard(
              title: context.l10n.messageGetUid,
              subtitle: context.l10n.messageGetCardUid,
              icon: Icons.credit_card,
              onTap: () => _execute(HfMfdesCmd.getuid())),
          ActionCard(
              title: context.l10n.messageFreeMemory,
              subtitle: context.l10n.messageViewAvailableMemory,
              icon: Icons.storage,
              onTap: () => _execute(HfMfdesCmd.freemem())),
          ActionCard(
              title: context.l10n.messageCheckKeys,
              subtitle: context.l10n.messageCheckDefaultKeys,
              icon: Icons.security,
              onTap: () => _execute(HfMfdesCmd.chk())),
          ActionCard(
              title: 'MAD',
              subtitle: context.l10n.messageViewApplicationDirectory,
              icon: Icons.list_alt,
              onTap: () => _execute(HfMfdesCmd.mad())),
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

  Widget _buildAppTab() {
    return SplitPageLayout(
      sideWidth: 300,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(
              onPressed: () => _execute(HfMfdesCmd.getaids()),
              icon: const Icon(Icons.list, size: 18),
              label: Text(context.l10n.messageListAids)),
          ElevatedButton.icon(
              onPressed: () => _execute(HfMfdesCmd.lsapp()),
              icon: const Icon(Icons.apps, size: 18),
              label: Text(context.l10n.messageListApplications)),
        ]),
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageSelectApplication,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: context.l10n.messageAid3ByteHex,
                        byteLength: 3,
                        onChanged: (v) => _aid = v,
                        prefixIcon: Icons.apps),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _aid.length == 6
                            ? () => _execute(HfMfdesCmd.selectapp(_aid))
                            : null,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text(context.l10n.messageSelect)),
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

  Widget _buildFileTab() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(
              onPressed: () => _execute(HfMfdesCmd.getfileids()),
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(context.l10n.messageListFiles)),
          ElevatedButton.icon(
              onPressed: () => _execute(HfMfdesCmd.lsfiles()),
              icon: const Icon(Icons.description, size: 18),
              label: Text(context.l10n.messageFileDetails)),
          ElevatedButton.icon(
              onPressed: () =>
                  _execute(HfMfdesCmd.dump(aid: _aid.isEmpty ? null : _aid)),
              icon: const Icon(Icons.download, size: 18),
              label: Text(context.l10n.messageDumpApplication)),
        ]),
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageFileReadWrite,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: 'FID',
                        byteLength: 1,
                        onChanged: (v) => _fid = v,
                        prefixIcon: Icons.tag),
                    const SizedBox(height: 8),
                    Wrap(runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: _fid.isNotEmpty
                              ? () => _execute(HfMfdesCmd.read(
                                  aid: _aid.isEmpty ? null : _aid, fid: _fid))
                              : null,
                          icon: const Icon(Icons.visibility, size: 18),
                          label: Text(context.l10n.messageRead)),
                    ]),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: context.l10n.messageWriteDataHex,
                        onChanged: (v) => _writeData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _writeData.isNotEmpty && _fid.isNotEmpty
                            ? () => _execute(HfMfdesCmd.write(_writeData,
                                aid: _aid.isEmpty ? null : _aid, fid: _fid))
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

  Widget _buildManageTab() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageAuthenticate,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.messageKeyNumber),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (v) => _keyNumber = int.tryParse(v) ?? 0,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _algorithm,
                          decoration: InputDecoration(
                            labelText: context.l10n.messageAlgorithm,
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'aes', child: Text('AES')),
                            DropdownMenuItem(value: 'des', child: Text('DES')),
                            DropdownMenuItem(
                                value: '3des', child: Text('3DES')),
                          ],
                          onChanged: (v) =>
                              setState(() => _algorithm = v ?? 'aes'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: context.l10n.messageKeyHex,
                        byteLength: 16,
                        onChanged: (v) => _key = v,
                        prefixIcon: Icons.vpn_key),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _key.isNotEmpty
                            ? () => _execute(HfMfdesCmd.auth(
                                _keyNumber.toString(), _key,
                                algo: _algorithm))
                            : null,
                        icon: const Icon(Icons.lock_open, size: 18),
                        label: Text(context.l10n.messageAuthenticate)),
                  ],
                ))),
        const SizedBox(height: 12),
        ActionCard(
            title: context.l10n.messageKeySettings,
            subtitle: context.l10n.messageGetKeySettings,
            icon: Icons.settings,
            onTap: () => _execute(HfMfdesCmd.getkeysettings())),
        ActionCard(
            title: context.l10n.messageFormatPicc,
            subtitle: context.l10n.messageDeleteAllApplicationsAndData,
            icon: Icons.delete_forever,
            onTap: () => _confirmThenExecute(
                context.l10n.messageConfirmFormat,
                context.l10n.messageThisWillDeleteAllApplicationsAndData,
                HfMfdesCmd.formatpicc())),
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
